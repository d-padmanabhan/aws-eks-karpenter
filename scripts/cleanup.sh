#!/bin/bash
set -e

echo "=========================================="
echo "Cleaning Up Todo App Resources"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${RED}WARNING: This will delete all resources including data in DynamoDB!${NC}"
echo -e "${YELLOW}Are you sure you want to continue? (type 'yes' to confirm)${NC}"
read -r response

if [ "$response" != "yes" ]; then
    echo -e "${GREEN}Cleanup cancelled${NC}"
    exit 0
fi

# Delete Kubernetes resources
echo -e "\n${YELLOW}Deleting Kubernetes resources...${NC}"
if kubectl get namespace todo-app > /dev/null 2>&1; then
    kubectl delete -f k8s/ingress.yaml --ignore-not-found=true
    kubectl delete -f k8s/frontend/ --ignore-not-found=true
    kubectl delete -f k8s/backend/ --ignore-not-found=true
    kubectl delete -f k8s/namespace.yaml --ignore-not-found=true
    echo -e "${GREEN}✓ Kubernetes resources deleted${NC}"
else
    echo -e "${YELLOW}Namespace todo-app not found, skipping...${NC}"
fi

# Wait for Load Balancer to be deleted
echo -e "\n${YELLOW}Waiting for Load Balancer to be deleted...${NC}"
sleep 30

# Destroy Terraform infrastructure
echo -e "\n${YELLOW}Destroying Terraform infrastructure...${NC}"
cd terraform

if [ -f "terraform.tfstate" ]; then
    terraform destroy -auto-approve
    echo -e "${GREEN}✓ Infrastructure destroyed${NC}"
else
    echo -e "${YELLOW}No Terraform state found, skipping...${NC}"
fi

cd ..

echo -e "\n${GREEN}=========================================="
echo -e "Cleanup complete!"
echo -e "==========================================${NC}"
