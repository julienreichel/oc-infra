#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="oc-local"

echo "==> Deleting k3d cluster '${CLUSTER_NAME}'..."
k3d cluster delete "${CLUSTER_NAME}" || true

echo "==> (optional) removing local images built for this project"
# comment out if you want to keep images
docker rmi local/oc-provider-backend:dev  >/dev/null 2>&1 || true
docker rmi local/oc-provider-frontend:dev >/dev/null 2>&1 || true
docker rmi local/oc-client-backend:dev    >/dev/null 2>&1 || true
docker rmi local/oc-client-frontend:dev   >/dev/null 2>&1 || true

echo "✅ Local OC environment has been removed."
echo "You can recreate it with: ./scripts/setup-local.sh"
