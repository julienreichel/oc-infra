#!/usr/bin/env bash
# Quick status check for OC local development

echo "🚀 OC Dev Status"

# Check local ports  
echo -n "Local: "
local_services=""
lsof -i :3000 >/dev/null 2>&1 && local_services="${local_services}client-be "
lsof -i :3001 >/dev/null 2>&1 && local_services="${local_services}provider-be "
lsof -i :8080 >/dev/null 2>&1 && local_services="${local_services}provider-fe "
lsof -i :9000 >/dev/null 2>&1 && local_services="${local_services}client-fe "
[ -n "$local_services" ] && echo "$local_services" || echo "none"

# Check K8s deployments with non-zero replicas
echo -n "K8s:   "
k8s_services=""
kubectl -n oc-provider get deployment oc-provider-backend -o jsonpath='{.spec.replicas}' 2>/dev/null | grep -q '^[1-9]' && k8s_services="${k8s_services}provider-be "
kubectl -n oc-provider get deployment oc-provider-frontend -o jsonpath='{.spec.replicas}' 2>/dev/null | grep -q '^[1-9]' && k8s_services="${k8s_services}provider-fe "
kubectl -n oc-client get deployment oc-client-backend -o jsonpath='{.spec.replicas}' 2>/dev/null | grep -q '^[1-9]' && k8s_services="${k8s_services}client-be "
kubectl -n oc-client get deployment oc-client-frontend -o jsonpath='{.spec.replicas}' 2>/dev/null | grep -q '^[1-9]' && k8s_services="${k8s_services}client-fe "
[ -n "$k8s_services" ] && echo "$k8s_services" || echo "none"

# Check ingress routing for backends
echo -n "→ API: "
provider_backend_service=$(kubectl -n oc-provider get ingress oc-provider-ingress -o jsonpath="{.spec.rules[0].http.paths[?(@.path=='/api')].backend.service.name}" 2>/dev/null)
client_backend_service=$(kubectl -n oc-client get ingress oc-client-ingress -o jsonpath="{.spec.rules[0].http.paths[?(@.path=='/api')].backend.service.name}" 2>/dev/null)

routing=""
[[ "$provider_backend_service" == *"-dev" ]] && routing="${routing}provider-local " || routing="${routing}provider-k8s "
[[ "$client_backend_service" == *"-dev" ]] && routing="${routing}client-local" || routing="${routing}client-k8s"
echo "$routing"

echo "URLs: https://provider.localhost | https://client.localhost"