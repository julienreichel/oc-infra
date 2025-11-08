#!/usr/bin/env bash
set -euo pipefail

echo "🔧 Fixing TLS settings for K8s backend deployments..."

# Function to add NODE_TLS_REJECT_UNAUTHORIZED env var to a deployment
fix_deployment_tls() {
    local namespace=$1
    local deployment=$2
    
    echo "   Checking $deployment in $namespace..."
    
    # Check if deployment exists
    if ! kubectl -n "$namespace" get deployment "$deployment" >/dev/null 2>&1; then
        echo "   ⚠️  Deployment $deployment not found in $namespace, skipping..."
        return
    fi
    
    # Check if envFrom config secret is already configured
    if kubectl -n "$namespace" get deployment "$deployment" -o jsonpath='{.spec.template.spec.containers[0].envFrom}' | grep -q '"name":"config"'; then
        echo "   ✅ envFrom config secret already configured for $deployment (NODE_TLS_REJECT_UNAUTHORIZED available)"
        return
    fi
    
    echo "   🔧 Adding envFrom config secret to $deployment..."
    
    # Check if envFrom array exists, if not create it
    if ! kubectl -n "$namespace" get deployment "$deployment" -o jsonpath='{.spec.template.spec.containers[0].envFrom}' | grep -q '\['; then
        # Create envFrom array with config secret
        kubectl -n "$namespace" patch deployment "$deployment" --type='json' -p='[
            {
                "op": "add",
                "path": "/spec/template/spec/containers/0/envFrom",
                "value": [{"secretRef": {"name": "config"}}]
            }
        ]'
    else
        # Add config secret to existing envFrom array
        kubectl -n "$namespace" patch deployment "$deployment" --type='json' -p='[
            {
                "op": "add",
                "path": "/spec/template/spec/containers/0/envFrom/-",
                "value": {"secretRef": {"name": "config"}}
            }
        ]'
    fi || {
        echo "   ⚠️  Failed to patch $deployment"
        echo "   💡 You may need to add this manually to the deployment manifest:"
        echo "      envFrom:"
        echo "        - secretRef:"
        echo "            name: config"
    }
}

# Fix both backend deployments
fix_deployment_tls "oc-provider" "oc-provider-backend"
fix_deployment_tls "oc-client" "oc-client-backend"

echo ""
echo "✅ TLS fix completed!"
echo ""
echo "💡 Next steps:"
echo "   1. The deployments should automatically restart with new env vars"
echo "   2. Test inter-service communication: provider backend → client backend"
echo "   3. If issues persist, check the deployment logs:"
echo "      kubectl logs -n oc-provider deployment/oc-provider-backend"
echo "      kubectl logs -n oc-client deployment/oc-client-backend"
echo ""
echo "🔍 To verify the fix worked:"
echo "   kubectl -n oc-provider get deployment oc-provider-backend -o yaml | grep -A5 NODE_TLS_REJECT_UNAUTHORIZED"