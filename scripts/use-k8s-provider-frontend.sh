#!/usr/bin/env bash
set -euo pipefail

NS="oc-provider"
FRONTEND_DEPLOYMENT="oc-provider-frontend"
INGRESS_NAME="oc-provider-ingress"

echo "Switching back to k8s frontend..."

# 1️⃣ Patch ingress to route /api back to k8s frontend
echo "Patching ingress $INGRESS_NAME to use k8s frontend..."
kubectl -n "$NS" patch ingress "$INGRESS_NAME" --type='json' \
  -p='[
    {"op":"replace","path":"/spec/rules/0/http/paths/0/backend/service/name","value":"oc-provider-frontend"},
    {"op":"replace","path":"/spec/rules/0/http/paths/0/backend/service/port/number","value":80}
  ]'

# 2️⃣ Scale up k8s frontend deployment
echo "Scaling up $FRONTEND_DEPLOYMENT..."
kubectl -n "$NS" scale deployment "$FRONTEND_DEPLOYMENT" --replicas=1

# 3️⃣ Remove dev service (ExternalName service)
echo "Cleaning up dev service..."
kubectl -n "$NS" delete service oc-provider-frontend-dev --ignore-not-found=true


echo "Frontend and ingress restored to cluster version."
