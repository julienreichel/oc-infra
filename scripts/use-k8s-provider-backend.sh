#!/usr/bin/env bash
set -euo pipefail

NS="oc-provider"
BACKEND_DEPLOYMENT="oc-provider-backend"
INGRESS_NAME="oc-provider-ingress"
DB_SERVICE="pg"
PID_FILE="/tmp/port-forward-${NS}-${DB_SERVICE}.pid"

echo "Switching back to k8s backend..."

# 1️⃣ Patch ingress to route /api back to k8s backend
echo "Patching ingress $INGRESS_NAME to use k8s backend..."
kubectl -n "$NS" patch ingress "$INGRESS_NAME" --type='json' \
  -p='[
    {"op":"replace","path":"/spec/rules/0/http/paths/1/backend/service/name","value":"oc-provider-backend"},
    {"op":"replace","path":"/spec/rules/0/http/paths/1/backend/service/port/number","value":80}
  ]'

# 2️⃣ Scale up k8s backend deployment
echo "Scaling up $BACKEND_DEPLOYMENT..."
kubectl -n "$NS" scale deployment "$BACKEND_DEPLOYMENT" --replicas=1

# 3️⃣ Remove dev service (ExternalName service)
echo "Cleaning up dev service..."
kubectl -n "$NS" delete service oc-provider-backend-dev --ignore-not-found=true

if [[ -f "$PID_FILE" ]]; then
  echo "Stopping port-forward..."
  kill "$(cat "$PID_FILE")" || true
  rm -f "$PID_FILE"
fi

echo "Backend and ingress restored to cluster version."
echo ""
echo "💡 Note: If you have a local backend running on port 3001, you may want to stop it to avoid confusion."
echo "   Check with: lsof -i :3001"
echo "   Kill with: pkill -f 'node.*3001' (or stop your dev server manually)"
