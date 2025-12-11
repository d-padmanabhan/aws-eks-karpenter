#!/bin/bash
set -e

echo "=========================================="
echo "Deploying Todo App to Kubernetes"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if kubectl is configured
if ! kubectl cluster-info > /dev/null 2>&1; then
    echo -e "${RED}Error: kubectl is not configured or cluster is not accessible${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Cluster is accessible${NC}"

# Check if AWS Load Balancer Controller is installed
echo -e "\n${YELLOW}Checking AWS Load Balancer Controller...${NC}"
if ! kubectl get deployment -n kube-system aws-load-balancer-controller > /dev/null 2>&1; then
    echo -e "${RED}Warning: AWS Load Balancer Controller not found${NC}"
    echo -e "${YELLOW}Please install it before proceeding (see k8s/aws-load-balancer-controller.yaml)${NC}"
    echo -e "\n${YELLOW}Do you want to continue anyway? (yes/no)${NC}"
    read -r response
    if [ "$response" != "yes" ]; then
        exit 1
    fi
else
    echo -e "${GREEN}✓ AWS Load Balancer Controller is installed${NC}"
fi

# Deploy namespace
echo -e "\n${YELLOW}Creating namespace...${NC}"
kubectl apply -f k8s/namespace.yaml

# Deploy backend
echo -e "\n${YELLOW}Deploying backend...${NC}"
kubectl apply -f k8s/backend/

# Wait for backend to be ready
echo -e "\n${YELLOW}Waiting for backend pods to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=backend -n todo-app --timeout=300s || true

# Deploy frontend
echo -e "\n${YELLOW}Deploying frontend...${NC}"
kubectl apply -f k8s/frontend/

# Wait for frontend to be ready
echo -e "\n${YELLOW}Waiting for frontend pods to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=frontend -n todo-app --timeout=300s || true

# Deploy ingress
echo -e "\n${YELLOW}Deploying ingress...${NC}"
kubectl apply -f k8s/ingress.yaml

# Wait for ingress to get an address
echo -e "\n${YELLOW}Waiting for Load Balancer to be provisioned (this may take a few minutes)...${NC}"
sleep 10

# Get ingress URL
echo -e "\n${YELLOW}Getting application URL...${NC}"
for i in {1..30}; do
    LB_URL=$(kubectl get ingress todo-app-ingress -n todo-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    if [ -n "$LB_URL" ]; then
        break
    fi
    echo -e "${YELLOW}Waiting for Load Balancer... ($i/30)${NC}"
    sleep 10
done

echo -e "\n${GREEN}=========================================="
echo -e "Application deployed successfully!"
echo -e "==========================================${NC}"

if [ -n "$LB_URL" ]; then
    echo -e "\n${GREEN}Application URL: http://${LB_URL}${NC}"
    echo -e "\nAPI Health Check: http://${LB_URL}/api/health/"
else
    echo -e "\n${YELLOW}Load Balancer URL not available yet. Check with:${NC}"
    echo -e "kubectl get ingress todo-app-ingress -n todo-app"
fi

echo -e "\n${YELLOW}Useful commands:${NC}"
echo -e "View pods:        kubectl get pods -n todo-app"
echo -e "View services:    kubectl get svc -n todo-app"
echo -e "View ingress:     kubectl get ingress -n todo-app"
echo -e "View HPA:         kubectl get hpa -n todo-app"
echo -e "Backend logs:     kubectl logs -f deployment/backend -n todo-app"
echo -e "Frontend logs:    kubectl logs -f deployment/frontend -n todo-app"
