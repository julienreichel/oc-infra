#!/usr/bin/env bash
set -euo pipefail

NS="oc-client"
BACKEND_DEPLOYMENT="oc-client-backend"
DEV_SERVICE_FILE="k8s/oc-client-backend-dev-svc.yaml"
INGRESS_NAME="oc-client-ingress"
DB_SERVICE="pg"
LOCAL_DB_PORT=5432
REMOTE_DB_PORT=5432

echo "Switching to local backend mode..."

# 1️⃣ Stop backend in cluster
echo "Scaling down $BACKEND_DEPLOYMENT..."
kubectl -n "$NS" scale deployment "$BACKEND_DEPLOYMENT" --replicas=0

# 2️⃣ Apply ExternalName service to reach localhost:3000
echo "Applying ExternalName service..."
kubectl apply -f "$DEV_SERVICE_FILE"

# 3️⃣ Patch ingress to route /api to local backend
echo "Patching ingress $INGRESS_NAME to use local backend..."
kubectl -n "$NS" patch ingress "$INGRESS_NAME" --type='json' \
  -p='[
    {"op":"replace","path":"/spec/rules/0/http/paths/1/backend/service/name","value":"oc-client-backend-dev"},
    {"op":"replace","path":"/spec/rules/0/http/paths/1/backend/service/port/number","value":3000}
  ]'

# 4️⃣ Port-forward Postgres to localhost
echo "Starting port-forward from $DB_SERVICE:$REMOTE_DB_PORT → localhost:$LOCAL_DB_PORT..."

# Kill any previous forward on that port
PID_FILE="/tmp/port-forward-${NS}-${DB_SERVICE}.pid"
if [[ -f "$PID_FILE" ]]; then
  OLD_PID=$(cat "$PID_FILE")
  if ps -p "$OLD_PID" > /dev/null 2>&1; then
    echo "🔪 Killing old port-forward process ($OLD_PID)..."
    kill "$OLD_PID" || true
  fi
  rm -f "$PID_FILE"
fi

kubectl -n "$NS" port-forward svc/$DB_SERVICE ${LOCAL_DB_PORT}:${REMOTE_DB_PORT} >/dev/null 2>&1 &
PF_PID=$!
echo $PF_PID > "$PID_FILE"
sleep 2
echo "Port-forward active (PID: $PF_PID). To stop it: kill \$(cat $PID_FILE)"
echo "Postgres URL: postgresql://app:StrongLocalPass@localhost:${LOCAL_DB_PORT}/db"

echo "Done! Your local backend on http://localhost:3000 now handles /api for https://client.localhost"
