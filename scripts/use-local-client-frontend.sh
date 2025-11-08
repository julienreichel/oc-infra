#!/usr/bin/env bash
set -euo pipefail

NS="oc-client"
FRONTEND_DEPLOYMENT="oc-client-frontend"
DEV_SERVICE_FILE="k8s/oc-client-frontend-dev-svc.yaml"
INGRESS_NAME="oc-client-ingress"

echo "Switching to local frontend mode..."

# 1️⃣ Stop frontend in cluster
echo "Scaling down $FRONTEND_DEPLOYMENT..."
kubectl -n "$NS" scale deployment "$FRONTEND_DEPLOYMENT" --replicas=0

# 2️⃣ Apply ExternalName service to reach localhost:3000
echo "Applying ExternalName service..."
kubectl apply -f "$DEV_SERVICE_FILE"

# 3️⃣ Patch ingress to route /api to local frontend
echo "Patching ingress $INGRESS_NAME to use local frontend..."
kubectl -n "$NS" patch ingress "$INGRESS_NAME" --type='json' \
  -p='[
    {"op":"replace","path":"/spec/rules/0/http/paths/0/backend/service/name","value":"oc-client-frontend-dev"},
    {"op":"replace","path":"/spec/rules/0/http/paths/0/backend/service/port/number","value":9000}
  ]'


echo "Done! Your local frontend on http://localhost:6000 now handles /api for https://client.localhost"
