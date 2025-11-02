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

# 3. ingress-nginx
echo "==> Installing ingress-nginx..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace oc-gateway \
  --create-namespace \
  --set controller.ingressClass=nginx \
  --set controller.ingressClassResource.name=nginx \
  --set controller.watchIngressWithoutClass=true

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
echo "==> Deploying provider Postgres..."
kubectl apply -n oc-provider -f "${K8S_DIR}/provider-postgres.yaml"
kubectl apply -n oc-provider -f "${K8S_DIR}/providersecret-db.yaml"

echo "==> Deploying client Postgres..."
kubectl apply -n oc-client -f "${K8S_DIR}/client-postgres.yaml"
kubectl apply -n oc-client -f "${K8S_DIR}/client-secret-db.yaml"

echo "==> Waiting for Postgres pods to be ready..."
kubectl wait --for=condition=ready pod -l app=oc-provider-pg -n oc-provider --timeout=60s || true
kubectl wait --for=condition=ready pod -l app=oc-client-pg -n oc-client --timeout=60s || true

# 7. Deploy apps (call the other script)
echo "==> Deploying apps (calling redeploy-apps.sh)…"
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/redeploy-apps.sh"

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
