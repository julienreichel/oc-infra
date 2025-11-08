#!/usr/bin/env bash
set -euo pipefail

echo "🔍 OC Local Development Status Check"
echo "====================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper function to check if a port is listening locally
check_local_port() {
    local port=$1
    if lsof -i :$port >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Running locally on port $port${NC}"
        return 0
    else
        echo -e "${RED}✗ Not running locally on port $port${NC}"
        return 1
    fi
}

# Helper function to check K8s service status
check_k8s_service() {
    local namespace=$1
    local service=$2
    local deployment=$3
    
    # Check if deployment exists and has replicas
    if kubectl -n "$namespace" get deployment "$deployment" >/dev/null 2>&1; then
        local replicas=$(kubectl -n "$namespace" get deployment "$deployment" -o jsonpath='{.spec.replicas}')
        local ready_replicas=$(kubectl -n "$namespace" get deployment "$deployment" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        
        if [ "$replicas" -gt 0 ] && [ "$ready_replicas" -gt 0 ]; then
            echo -e "${GREEN}✓ K8s deployment running ($ready_replicas/$replicas ready)${NC}"
            return 0
        elif [ "$replicas" -gt 0 ]; then
            echo -e "${YELLOW}⚠ K8s deployment exists but not ready ($ready_replicas/$replicas ready)${NC}"
            return 1
        else
            echo -e "${BLUE}○ K8s deployment scaled down (0 replicas)${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ K8s deployment not found${NC}"
        return 1
    fi
}

# Helper function to check ingress routing
check_ingress_routing() {
    local namespace=$1
    local ingress_name=$2
    local path=$3
    local expected_service=$4
    
    local actual_service=$(kubectl -n "$namespace" get ingress "$ingress_name" -o jsonpath="{.spec.rules[0].http.paths[?(@.path=='$path')].backend.service.name}" 2>/dev/null || echo "")
    
    if [ "$actual_service" = "$expected_service" ]; then
        echo -e "${GREEN}✓ Ingress routes $path to $expected_service${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Ingress routes $path to $actual_service (expected: $expected_service)${NC}"
        return 1
    fi
}

# Helper function to check if local dev service exists
check_dev_service() {
    local namespace=$1
    local service_name=$2
    
    if kubectl -n "$namespace" get service "$service_name" >/dev/null 2>&1; then
        echo -e "${BLUE}○ Dev service exists ($service_name)${NC}"
        return 0
    else
        echo -e "${RED}✗ Dev service not found ($service_name)${NC}"
        return 1
    fi
}

echo ""
echo "🎯 Provider Services"
echo "-------------------"

echo -n "Frontend (Local):  "
provider_frontend_local=false
if check_local_port 8080; then
    provider_frontend_local=true
fi

echo -n "Frontend (K8s):    "
provider_frontend_k8s=false
if check_k8s_service "oc-provider" "oc-provider-frontend" "oc-provider-frontend"; then
    provider_frontend_k8s=true
fi

echo -n "Backend (Local):   "
provider_backend_local=false
if check_local_port 3001; then
    provider_backend_local=true
fi

echo -n "Backend (K8s):     "
provider_backend_k8s=false
if check_k8s_service "oc-provider" "oc-provider-backend" "oc-provider-backend"; then
    provider_backend_k8s=true
fi

echo ""
echo "🎯 Client Services"  
echo "-----------------"

echo -n "Frontend (Local):  "
client_frontend_local=false
if check_local_port 9000; then
    client_frontend_local=true
fi

echo -n "Frontend (K8s):    "
client_frontend_k8s=false
if check_k8s_service "oc-client" "oc-client-frontend" "oc-client-frontend"; then
    client_frontend_k8s=true
fi

echo -n "Backend (Local):   "
client_backend_local=false
if check_local_port 3000; then
    client_backend_local=true
fi

echo -n "Backend (K8s):     "
client_backend_k8s=false  
if check_k8s_service "oc-client" "oc-client-backend" "oc-client-backend"; then
    client_backend_k8s=true
fi

echo ""
echo "🔀 Ingress Routing (Where Traffic Goes)"
echo "--------------------------------------"

# Provider routing
echo "Provider:"
echo -n "  Frontend (/):    "
check_ingress_routing "oc-provider" "oc-provider-ingress" "/" "oc-provider-frontend"

echo -n "  Backend (/api):  "
provider_backend_service=$(kubectl -n oc-provider get ingress oc-provider-ingress -o jsonpath="{.spec.rules[0].http.paths[?(@.path=='/api')].backend.service.name}" 2>/dev/null || echo "")
if [ "$provider_backend_service" = "oc-provider-backend-dev" ]; then
    echo -e "${YELLOW}→ Local Backend (via dev service)${NC}"
elif [ "$provider_backend_service" = "oc-provider-backend" ]; then
    echo -e "${BLUE}→ K8s Backend${NC}"
else
    echo -e "${RED}✗ Unknown service: $provider_backend_service${NC}"
fi

# Client routing  
echo "Client:"
echo -n "  Frontend (/):    "
check_ingress_routing "oc-client" "oc-client-ingress" "/" "oc-client-frontend"

echo -n "  Backend (/api):  "
client_backend_service=$(kubectl -n oc-client get ingress oc-client-ingress -o jsonpath="{.spec.rules[0].http.paths[?(@.path=='/api')].backend.service.name}" 2>/dev/null || echo "")
if [ "$client_backend_service" = "oc-client-backend-dev" ]; then
    echo -e "${YELLOW}→ Local Backend (via dev service)${NC}"
elif [ "$client_backend_service" = "oc-client-backend" ]; then
    echo -e "${BLUE}→ K8s Backend${NC}"
else
    echo -e "${RED}✗ Unknown service: $client_backend_service${NC}"
fi

echo ""
echo "📊 Traffic Summary"
echo "-----------------"

# Check where traffic actually goes based on ingress
provider_backend_service=$(kubectl -n oc-provider get ingress oc-provider-ingress -o jsonpath="{.spec.rules[0].http.paths[?(@.path=='/api')].backend.service.name}" 2>/dev/null || echo "")
client_backend_service=$(kubectl -n oc-client get ingress oc-client-ingress -o jsonpath="{.spec.rules[0].http.paths[?(@.path=='/api')].backend.service.name}" 2>/dev/null || echo "")

echo -n "Provider Traffic:  "
if [ "$provider_backend_service" = "oc-provider-backend-dev" ]; then
    echo -e "${YELLOW}Frontend K8s + Backend Local${NC}"
elif [ "$provider_backend_service" = "oc-provider-backend" ]; then
    echo -e "${BLUE}Full Kubernetes${NC}"
else
    echo -e "${RED}Configuration Issue${NC}"
fi

echo -n "Client Traffic:    "
if [ "$client_backend_service" = "oc-client-backend-dev" ]; then
    echo -e "${YELLOW}Frontend K8s + Backend Local${NC}" 
elif [ "$client_backend_service" = "oc-client-backend" ]; then
    echo -e "${BLUE}Full Kubernetes${NC}"
else  
    echo -e "${RED}Configuration Issue${NC}"
fi

echo ""
echo "🌐 Access URLs"
echo "--------------"
echo "Provider: https://provider.localhost"
echo "Client:   https://client.localhost"

if $provider_backend_local; then
    echo "Provider Backend (direct): http://localhost:3001"
fi

if $client_backend_local; then
    echo "Client Backend (direct): http://localhost:3000"  
fi

if $provider_frontend_local; then
    echo "Provider Frontend (dev): http://localhost:9001"
fi

if $client_frontend_local; then
    echo "Client Frontend (dev): http://localhost:9000"
fi

echo ""
echo "💡 Available Commands"
echo "--------------------"
echo "./scripts/use-local-provider-backend.sh   - Switch provider backend to local"
echo "./scripts/use-k8s-provider-backend.sh     - Switch provider backend to K8s"
echo "./scripts/use-local-client-backend.sh     - Switch client backend to local"  
echo "./scripts/use-k8s-client-backend.sh       - Switch client backend to K8s"
echo "./scripts/local-backend-env.sh            - Show local backend env vars"

