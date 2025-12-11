#!/bin/bash
set -e

echo "=========================================="
echo "Installing Karpenter"
echo "=========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check prerequisites
echo -e "\n${YELLOW}Checking prerequisites...${NC}"

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    exit 1
fi

if ! command -v helm &> /dev/null; then
    echo -e "${RED}Error: helm is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites met${NC}"

# Get cluster info
CLUSTER_NAME=${1:-todo-app-cluster}
AWS_REGION=${2:-us-east-1}
KARPENTER_VERSION=${3:-v0.33.0}

echo -e "\n${YELLOW}Configuration:${NC}"
echo "Cluster Name: $CLUSTER_NAME"
echo "AWS Region: $AWS_REGION"
echo "Karpenter Version: $KARPENTER_VERSION"

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account: $ACCOUNT_ID"

# Get Karpenter IAM role ARN from Terraform
cd ../../../terraform
KARPENTER_ROLE_ARN=$(terraform output -raw karpenter_controller_role_arn 2>/dev/null || echo "")
KARPENTER_INSTANCE_PROFILE=$(terraform output -raw karpenter_node_instance_profile_name 2>/dev/null || echo "")
KARPENTER_QUEUE_NAME=$(terraform output -raw karpenter_queue_name 2>/dev/null || echo "")
cd -

if [ -z "$KARPENTER_ROLE_ARN" ]; then
    echo -e "${RED}Error: Could not get Karpenter role ARN from Terraform${NC}"
    echo "Make sure Terraform has been applied successfully"
    exit 1
fi

echo -e "\n${YELLOW}Karpenter Configuration:${NC}"
echo "Controller Role ARN: $KARPENTER_ROLE_ARN"
echo "Instance Profile: $KARPENTER_INSTANCE_PROFILE"
echo "Queue Name: $KARPENTER_QUEUE_NAME"

# Logout of helm registry to perform an unauthenticated pull
helm registry logout public.ecr.aws || true

# Add Karpenter Helm repository
echo -e "\n${YELLOW}Adding Karpenter Helm repository...${NC}"
helm repo add karpenter https://charts.karpenter.sh/
helm repo update

# Create namespace
echo -e "\n${YELLOW}Creating Karpenter namespace...${NC}"
kubectl apply -f namespace.yaml

# Update service account with correct role ARN
echo -e "\n${YELLOW}Updating service account...${NC}"
cat > /tmp/karpenter-sa.yaml <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: karpenter
  namespace: karpenter
  annotations:
    eks.amazonaws.com/role-arn: ${KARPENTER_ROLE_ARN}
EOF

kubectl apply -f /tmp/karpenter-sa.yaml

# Install Karpenter using Helm
echo -e "\n${YELLOW}Installing Karpenter via Helm...${NC}"
helm upgrade --install karpenter karpenter/karpenter \
  --namespace karpenter \
  --version ${KARPENTER_VERSION} \
  --set serviceAccount.create=false \
  --set serviceAccount.name=karpenter \
  --set settings.clusterName=${CLUSTER_NAME} \
  --set settings.clusterEndpoint=$(aws eks describe-cluster --name ${CLUSTER_NAME} --region ${AWS_REGION} --query "cluster.endpoint" --output text) \
  --set settings.interruptionQueue=${KARPENTER_QUEUE_NAME} \
  --set controller.resources.requests.cpu=1 \
  --set controller.resources.requests.memory=1Gi \
  --set controller.resources.limits.cpu=1 \
  --set controller.resources.limits.memory=1Gi \
  --wait

# Wait for Karpenter to be ready
echo -e "\n${YELLOW}Waiting for Karpenter to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/karpenter -n karpenter

# Update NodePool and EC2NodeClass with correct values
echo -e "\n${YELLOW}Creating NodePool and EC2NodeClass...${NC}"
cat > /tmp/karpenter-nodepool.yaml <<EOF
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: default
spec:
  template:
    metadata:
      labels:
        workload-type: general
    spec:
      nodeClassRef:
        name: default
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand", "spot"]
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["t", "c", "m", "r"]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["2"]
        - key: karpenter.k8s.aws/instance-size
          operator: In
          values: ["small", "medium", "large"]
      taints: []
      startupTaints:
        - key: node.kubernetes.io/not-ready
          effect: NoSchedule
  limits:
    cpu: "100"
    memory: 200Gi
  disruption:
    consolidationPolicy: WhenUnderutilized
    consolidateAfter: 30s
    budgets:
      - nodes: "10%"
  weight: 10
---
apiVersion: karpenter.k8s.aws/v1beta1
kind: EC2NodeClass
metadata:
  name: default
spec:
  amiFamily: AL2
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: ${CLUSTER_NAME}
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: ${CLUSTER_NAME}
  role: ${KARPENTER_INSTANCE_PROFILE}
  userData: |
    #!/bin/bash
    /etc/eks/bootstrap.sh ${CLUSTER_NAME}
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeSize: 50Gi
        volumeType: gp3
        iops: 3000
        throughput: 125
        encrypted: true
        deleteOnTermination: true
  metadataOptions:
    httpEndpoint: enabled
    httpProtocolIPv6: disabled
    httpPutResponseHopLimit: 2
    httpTokens: required
  tags:
    Name: karpenter-node
    ManagedBy: karpenter
    Environment: production
    Project: todo-app
EOF

kubectl apply -f /tmp/karpenter-nodepool.yaml

# Verify installation
echo -e "\n${YELLOW}Verifying Karpenter installation...${NC}"
kubectl get pods -n karpenter
kubectl get nodepool
kubectl get ec2nodeclass

echo -e "\n${GREEN}=========================================="
echo -e "Karpenter installed successfully!"
echo -e "==========================================${NC}"
echo -e "\nUseful commands:"
echo -e "  View Karpenter logs:    kubectl logs -f -n karpenter -l app.kubernetes.io/name=karpenter"
echo -e "  View NodePools:         kubectl get nodepool"
echo -e "  View EC2NodeClasses:    kubectl get ec2nodeclass"
echo -e "  View Karpenter nodes:   kubectl get nodes -l karpenter.sh/nodepool=default"
echo -e "\nKarpenter will now automatically provision nodes based on pending pods!"
