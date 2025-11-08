#!/usr/bin/env bash
# Quick status check for OC local development

echo "🚀 OC Dev Status (Quick Check)"

# Check local ports
echo -n "Local: "
local_services=""
lsof -i :3000 >/dev/null 2>&1 && local_services="${local_services}client-backend "
lsof -i :3001 >/dev/null 2>&1 && local_services="${local_services}provider-backend "
lsof -i :8080 >/dev/null 2>&1 && local_services="${local_services}provider-frontend "
lsof -i :9000 >/dev/null 2>&1 && local_services="${local_services}client-frontend "

[ -n "$local_services" ] && echo "$local_services" || echo "none"

# Check K8s deployments with non-zero replicas
echo -n "K8s:   "
k8s_services=""
kubectl -n oc-provider get deployment oc-provider-backend -o jsonpath='{.spec.replicas}' 2>/dev/null | grep -q '^[1-9]' && k8s_services="${k8s_services}provider-backend "
kubectl -n oc-provider get deployment oc-provider-frontend -o jsonpath='{.spec.replicas}' 2>/dev/null | grep -q '^[1-9]' && k8s_services="${k8s_services}provider-frontend "
kubectl -n oc-client get deployment oc-client-backend -o jsonpath='{.spec.replicas}' 2>/dev/null | grep -q '^[1-9]' && k8s_services="${k8s_services}client-backend "
kubectl -n oc-client get deployment oc-client-frontend -o jsonpath='{.spec.replicas}' 2>/dev/null | grep -q '^[1-9]' && k8s_services="${k8s_services}client-frontend "

[ -n "$k8s_services" ] && echo "$k8s_services" || echo "none"

echo "URLs: https://provider.localhost | https://client.localhost"