#!/bin/bash
set -e

echo "=========================================="
echo "Deploying Todo App Infrastructure"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
echo -e "\n${YELLOW}Checking prerequisites...${NC}"

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Error: terraform is not installed${NC}"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: aws CLI is not installed${NC}"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ All prerequisites met${NC}"

# Navigate to terraform directory
cd terraform

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${YELLOW}terraform.tfvars not found. Creating from example...${NC}"
    cp terraform.tfvars.example terraform.tfvars
    echo -e "${RED}Please edit terraform.tfvars with your values and run this script again${NC}"
    exit 1
fi

# Initialize Terraform
echo -e "\n${YELLOW}Initializing Terraform...${NC}"
terraform init

# Validate configuration
echo -e "\n${YELLOW}Validating Terraform configuration...${NC}"
terraform validate

# Plan infrastructure
echo -e "\n${YELLOW}Planning infrastructure...${NC}"
terraform plan -out=tfplan

# Ask for confirmation
echo -e "\n${YELLOW}Do you want to apply this plan? (yes/no)${NC}"
read -r response

if [ "$response" != "yes" ]; then
    echo -e "${RED}Deployment cancelled${NC}"
    exit 0
fi

# Apply infrastructure
echo -e "\n${YELLOW}Applying infrastructure...${NC}"
terraform apply tfplan

# Get outputs
echo -e "\n${GREEN}Infrastructure deployed successfully!${NC}"
echo -e "\n${YELLOW}Terraform Outputs:${NC}"
terraform output

# Configure kubectl
echo -e "\n${YELLOW}Configuring kubectl...${NC}"
CLUSTER_NAME=$(terraform output -raw cluster_name)
AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")

aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

# Verify cluster access
echo -e "\n${YELLOW}Verifying cluster access...${NC}"
kubectl get nodes

# Save IRSA role ARN for later use
IRSA_ROLE_ARN=$(terraform output -raw backend_irsa_role_arn)
echo "$IRSA_ROLE_ARN" > ../k8s/backend/irsa-role-arn.txt

echo -e "\n${GREEN}=========================================="
echo -e "Infrastructure deployment complete!"
echo -e "==========================================${NC}"
echo -e "\nNext steps:"
echo -e "1. Install AWS Load Balancer Controller (see k8s/aws-load-balancer-controller.yaml)"
echo -e "2. Update k8s/backend/serviceaccount.yaml with IRSA role ARN: ${IRSA_ROLE_ARN}"
echo -e "3. Build and push Docker images"
echo -e "4. Deploy application using scripts/deploy-app.sh"
