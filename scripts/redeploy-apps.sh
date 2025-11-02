#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="oc-local"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORKSPACE_DIR="$(cd "${INFRA_DIR}/.." && pwd)"
K8S_DIR="${INFRA_DIR}/k8s"

echo "==> Redeploying apps into cluster '${CLUSTER_NAME}'"
echo "==> Workspace: ${WORKSPACE_DIR}"

# ---- helpers ------------------------------------------------

build_and_import () {
  local NAME="$1"      # e.g. oc-provider-backend
  local PATH_ABS="$2"  # e.g. /.../oc-provider-backend
  local IMAGE="local/${NAME}:dev"

  echo "   [build] ${NAME} → ${IMAGE}"
  (cd "${PATH_ABS}" && docker build -t "${IMAGE}" .)

  echo "   [import] ${IMAGE} → k3d:${CLUSTER_NAME}"
  k3d image import "${IMAGE}" -c "${CLUSTER_NAME}"
}

apply_service_if_exists () {
  local NS="$1"
  local FILE="$2"
  if [ -f "${FILE}" ]; then
    kubectl apply -n "${NS}" -f "${FILE}"
  fi
}

apply_ingress_if_exists () {
  local NS="$1"
  local FILE="$2"
  if [ -f "${FILE}" ]; then
    kubectl apply -n "${NS}" -f "${FILE}"
  fi
}

apply_deployment_with_image () {
  local NAME="$1"         # oc-provider-backend
  local NS="$2"           # oc-provider
  local DEPLOY_FILE="$3"  # /path/.../k8s/deployment.yaml
  local IMAGE="local/${NAME}:dev"

  if [ ! -f "${DEPLOY_FILE}" ]; then
    echo "   [warn] deployment file not found: ${DEPLOY_FILE}"
    return
  fi

  echo "   [apply] ${NAME} (ns=${NS}) with image ${IMAGE}"
  sed "s|IMAGE_PLACEHOLDER|${IMAGE}|g" "${DEPLOY_FILE}" | kubectl apply -n "${NS}" -f -
}

# ---- 1. build+import images ---------------------------------

echo "==> Building and importing images…"
build_and_import "oc-provider-backend"   "${WORKSPACE_DIR}/oc-provider-backend"
build_and_import "oc-provider-frontend"  "${WORKSPACE_DIR}/oc-provider-frontend"
build_and_import "oc-client-backend"     "${WORKSPACE_DIR}/oc-client-backend"
build_and_import "oc-client-frontend"    "${WORKSPACE_DIR}/oc-client-frontend"

# ---- 2. apply service/ingress from app repos ----------------

echo "==> Applying base k8s manifests from app repos…"

# provider backend
apply_service_if_exists  "oc-provider"  "${WORKSPACE_DIR}/oc-provider-backend/k8s/service.yaml"
# provider frontend
apply_service_if_exists  "oc-provider"  "${WORKSPACE_DIR}/oc-provider-frontend/k8s/service.yaml"
# client backend
apply_service_if_exists  "oc-client"    "${WORKSPACE_DIR}/oc-client-backend/k8s/service.yaml"
# client frontend
apply_service_if_exists  "oc-client"    "${WORKSPACE_DIR}/oc-client-frontend/k8s/service.yaml"

# (we don't apply app ingresses here, we use oc-infra/local ones instead)

# ---- 3. apply deployments with local images -----------------

echo "==> Applying deployments with local images (CI-style)…"

apply_deployment_with_image "oc-provider-backend"  "oc-provider"  "${WORKSPACE_DIR}/oc-provider-backend/k8s/deployment.yaml"
apply_deployment_with_image "oc-provider-frontend" "oc-provider"  "${WORKSPACE_DIR}/oc-provider-frontend/k8s/deployment.yaml"
apply_deployment_with_image "oc-client-backend"    "oc-client"    "${WORKSPACE_DIR}/oc-client-backend/k8s/deployment.yaml"
apply_deployment_with_image "oc-client-frontend"   "oc-client"    "${WORKSPACE_DIR}/oc-client-frontend/k8s/deployment.yaml"

# ---- 4. apply local ingresses -------------------------------

echo "==> Applying LOCAL ingress overrides (provider.localhost / client.localhost)…"
kubectl apply -f "${K8S_DIR}/local-ingress-provider.yaml"
kubectl apply -f "${K8S_DIR}/local-ingress-client.yaml"

echo "✅ Redeploy done."
