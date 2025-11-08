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
    
    # Check if the env var is already set
    if kubectl -n "$namespace" get deployment "$deployment" -o yaml | grep -q "NODE_TLS_REJECT_UNAUTHORIZED"; then
        echo "   ✅ NODE_TLS_REJECT_UNAUTHORIZED already configured for $deployment"
        return
    fi
    
    echo "   🔧 Adding NODE_TLS_REJECT_UNAUTHORIZED=0 to $deployment..."
    
    # Add the environment variable from the config secret
    kubectl -n "$namespace" patch deployment "$deployment" --type='json' -p='[
        {
            "op": "add",
            "path": "/spec/template/spec/containers/0/env/-",
            "value": {
                "name": "NODE_TLS_REJECT_UNAUTHORIZED",
                "valueFrom": {
                    "secretKeyRef": {
                        "name": "config",
                        "key": "NODE_TLS_REJECT_UNAUTHORIZED"
                    }
                }
            }
        }
    ]' || {
        echo "   ⚠️  Failed to patch $deployment (might already have env vars configured differently)"
        echo "   💡 You may need to add this manually to the deployment manifest:"
        echo "      env:"
        echo "        - name: NODE_TLS_REJECT_UNAUTHORIZED"
        echo "          valueFrom:"
        echo "            secretKeyRef:"
        echo "              name: config"
        echo "              key: NODE_TLS_REJECT_UNAUTHORIZED"
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