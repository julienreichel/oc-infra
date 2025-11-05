#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="oc-local"
K8S_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/k8s"
WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "==> Using workspace: $WORKSPACE_DIR"

# 1. Create k3d cluster (with traefik disabled!)
if k3d cluster list | grep -q "${CLUSTER_NAME}"; then
  echo "==> k3d cluster '${CLUSTER_NAME}' already exists, skipping creation"
else
  echo "==> Creating k3d cluster '${CLUSTER_NAME}'..."
  k3d cluster create "${CLUSTER_NAME}" \
    --agents 1 \
    --port "80:80@loadbalancer" \
    --port "443:443@loadbalancer" \
    --k3s-arg "--disable=traefik@server:0"
fi

echo "==> Switching kubectl context"
kubectl config use-context "k3d-${CLUSTER_NAME}" >/dev/null

# 2. Namespaces
echo "==> Creating namespaces (oc-gateway, oc-provider, oc-client)…"
kubectl apply -f "${K8S_DIR}/namespace.yaml"

# 3. Traefik
echo "==> Installing Traefik..."
helm repo add traefik https://traefik.github.io/charts >/dev/null
helm repo update >/dev/null
helm upgrade --install traefik traefik/traefik \
  --namespace oc-gateway \
  --create-namespace \
  --set ingressClass.enabled=true \
  --set ingressClass.isDefaultClass=true \
  --set service.type=LoadBalancer


# 4. cert-manager
echo "==> Installing cert-manager..."
helm repo add jetstack https://charts.jetstack.io >/dev/null
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true

# 5. self-signed issuer (local)
echo "==> Applying local self-signed ClusterIssuer (selfsigned-local)…"
kubectl apply -f "${K8S_DIR}/clusterissuer-selfsigned-local.yaml"

# 6. local Postgres
create_db_secrets () {
  local ns="$1"
  local db_name="$2"
  local db_user="$3"
  local db_pass="$4"

  echo "==> Creating/Updating DB secrets in namespace '${ns}'"
  # Secret used by the Postgres pod
  kubectl -n "${ns}" create secret generic db-secret \
    --from-literal=POSTGRES_DB="${db_name}" \
    --from-literal=POSTGRES_USER="${db_user}" \
    --from-literal=POSTGRES_PASSWORD="${db_pass}" \
    --dry-run=client -o yaml | kubectl apply -f -

  # Secret often used by apps (DATABASE_URL), service is 'pg' within the same ns
  kubectl -n "${ns}" create secret generic db \
    --from-literal=DATABASE_URL="postgres://${db_user}:${db_pass}@pg:5432/${db_name}" \
    --dry-run=client -o yaml | kubectl apply -f -

  # Create namespace-specific secret expected by deployments
  kubectl -n "${ns}" create secret generic "${ns}-db" \
    --from-literal=DATABASE_URL="postgres://${db_user}:${db_pass}@pg:5432/${db_name}" \
    --dry-run=client -o yaml | kubectl apply -f -
}

# Local defaults (same across namespaces; change if you want different creds per ns)
LOCAL_DB_NAME="db"
LOCAL_DB_USER="app"
LOCAL_DB_PASS="StrongLocalPass"   # or read from env if you prefer

create_db_secrets "oc-provider" "${LOCAL_DB_NAME}" "${LOCAL_DB_USER}" "${LOCAL_DB_PASS}"
create_db_secrets "oc-client"   "${LOCAL_DB_NAME}" "${LOCAL_DB_USER}" "${LOCAL_DB_PASS}"

echo "==> Deploying provider Postgres..."
kubectl apply -n oc-provider -f "${K8S_DIR}/postgres.yaml"

echo "==> Deploying client Postgres..."
kubectl apply -n oc-client -f "${K8S_DIR}/postgres.yaml"

echo "==> Waiting for Postgres pods to be ready..."
kubectl wait --for=condition=ready pod -l app=pg -n oc-provider --timeout=60s || true
kubectl wait --for=condition=ready pod -l app=pg -n oc-client --timeout=60s || true

# 7. Deploy apps (call the other script)
echo "==> Deploying apps (calling redeploy-apps.sh)…"
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/redeploy-apps.sh"

# 8. Run database migrations for backends
echo "==> Running database migrations..."

run_migration_if_exists() {
  local ns="$1"
  local app_dir="$2"
  
  if [[ -f "${app_dir}/k8s/migration-job.yaml" ]]; then
    echo "==> Running migration for ${ns}..."
    
    # Get job name from manifest
    JOB_NAME=$(grep -E "^  name:" "${app_dir}/k8s/migration-job.yaml" | awk '{print $2}')
    
    # Clean up any existing migration job
    kubectl delete job "${JOB_NAME}" -n "${ns}" --ignore-not-found=true
    kubectl wait --for=delete job/"${JOB_NAME}" -n "${ns}" --timeout=60s || true
    
    # Apply migration job with image substitution
    sed "s|IMAGE_PLACEHOLDER|local/${ns##*-}:dev|g" "${app_dir}/k8s/migration-job.yaml" | \
      kubectl -n "${ns}" apply -f -
    
    # Wait for migration to complete
    echo "   Waiting for migration job '${JOB_NAME}' to complete..."
    kubectl -n "${ns}" wait --for=condition=complete job/"${JOB_NAME}" --timeout=300s
    
    # Check status and show logs if failed
    JOB_STATUS=$(kubectl -n "${ns}" get job "${JOB_NAME}" -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>/dev/null || echo "False")
    if [[ "$JOB_STATUS" != "True" ]]; then
      echo "   ⚠️  Migration job failed. Logs:"
      kubectl -n "${ns}" logs job/"${JOB_NAME}" --tail=20 || true
    else
      echo "   ✅ Migration completed successfully"
    fi
  else
    echo "   No migration-job.yaml found for ${ns}, skipping..."
  fi
}

# Run migrations for each backend that has a migration job
run_migration_if_exists "oc-provider" "${WORKSPACE_DIR}/oc-provider-backend"
run_migration_if_exists "oc-client" "${WORKSPACE_DIR}/oc-client-backend"

echo ""
echo "======================================================"
echo "Local OC environment is up 🟢"
echo ""
echo "Add to /etc/hosts:"
echo "  127.0.0.1  provider.localhost"
echo "  127.0.0.1  client.localhost"
echo ""
echo "Open:"
echo "  https://provider.localhost"
echo "  https://client.localhost"
echo "======================================================"
