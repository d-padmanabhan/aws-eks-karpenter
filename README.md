# Production-Grade Todo App on Amazon EKS with Karpenter

A fully production-ready, cloud-native Todo application demonstrating modern DevOps practices, Kubernetes orchestration, and AWS infrastructure automation. This project showcases enterprise-grade deployment patterns using EKS, Karpenter auto-scaling, Infrastructure as Code (Terraform), and containerization best practices.

[![AWS](https://img.shields.io/badge/AWS-EKS-orange?logo=amazon-aws)](https://aws.amazon.com/eks/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.28-blue?logo=kubernetes)](https://kubernetes.io/)
[![Terraform](https://img.shields.io/badge/Terraform-1.0+-purple?logo=terraform)](https://www.terraform.io/)
[![Django](https://img.shields.io/badge/Django-5.0-green?logo=django)](https://www.djangoproject.com/)
[![React](https://img.shields.io/badge/React-18.2-blue?logo=react)](https://reactjs.org/)
[![Karpenter](https://img.shields.io/badge/Karpenter-v0.33.0-success)](https://karpenter.sh/)

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Features](#features)
- [Technology Stack](#technology-stack)
- [Pod Authentication Modes](#pod-authentication-modes)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Setup](#detailed-setup)
- [Project Structure](#project-structure)
- [Infrastructure](#infrastructure)
- [Karpenter Auto-Scaling](#karpenter-auto-scaling)
- [Deployment](#deployment)
- [Monitoring & Operations](#monitoring--operations)
- [Security](#security)
- [Cost Optimization](#cost-optimization)
- [Troubleshooting](#troubleshooting)
- [CI/CD](#cicd)
- [Contributing](#contributing)
- [License](#license)

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              AWS Cloud                                   │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │                         VPC (10.0.0.0/16)                      │    │
│  │                                                                 │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │    │
│  │  │ Public       │  │ Public       │  │ Public       │        │    │
│  │  │ Subnet       │  │ Subnet       │  │ Subnet       │        │    │
│  │  │ AZ-1         │  │ AZ-2         │  │ AZ-3         │        │    │
│  │  │              │  │              │  │              │        │    │
│  │  │  ┌────────┐  │  │              │  │              │        │    │
│  │  │  │ ALB    │  │  │              │  │              │        │    │
│  │  │  └────┬───┘  │  │              │  │              │        │    │
│  │  └───────┼──────┘  └──────────────┘  └──────────────┘        │    │
│  │          │                                                     │    │
│  │  ┌───────┼──────┐  ┌──────────────┐  ┌──────────────┐        │    │
│  │  │ Private      │  │ Private      │  │ Private      │        │    │
│  │  │ Subnet       │  │ Subnet       │  │ Subnet       │        │    │
│  │  │ AZ-1         │  │ AZ-2         │  │ AZ-3         │        │    │
│  │  │              │  │              │  │              │        │    │
│  │  │ ┌──────────┐ │  │ ┌──────────┐ │  │ ┌──────────┐ │        │    │
│  │  │ │EKS Nodes │ │  │ │EKS Nodes │ │  │ │EKS Nodes │ │        │    │
│  │  │ │          │ │  │ │          │ │  │ │          │ │        │    │
│  │  │ │┌────────┐│ │  │ │┌────────┐│ │  │ │┌────────┐│ │        │    │
│  │  │ ││Backend ││ │  │ ││Backend ││ │  │ ││Backend ││ │        │    │
│  │  │ ││Pods    ││ │  │ ││Pods    ││ │  │ ││Pods    ││ │        │    │
│  │  │ │└────────┘│ │  │ │└────────┘│ │  │ │└────────┘│ │        │    │
│  │  │ │┌────────┐│ │  │ │┌────────┐│ │  │ │┌────────┐│ │        │    │
│  │  │ ││Frontend││ │  │ ││Frontend││ │  │ ││Frontend││ │        │    │
│  │  │ ││Pods    ││ │  │ ││Pods    ││ │  │ ││Pods    ││ │        │    │
│  │  │ │└────────┘│ │  │ │└────────┘│ │  │ │└────────┘│ │        │    │
│  │  │ └──────────┘ │  │ └──────────┘ │  │ └──────────┘ │        │    │
│  │  └──────────────┘  └──────────────┘  └──────────────┘        │    │
│  │                                                                 │    │
│  │  ┌────────────────────────────────────────────────────────┐   │    │
│  │  │            EKS Control Plane (Managed)                 │   │    │
│  │  │  • Karpenter Controller (Auto-scaling)                 │   │    │
│  │  │  • AWS Load Balancer Controller                        │   │    │
│  │  │  • Metrics Server                                      │   │    │
│  │  └────────────────────────────────────────────────────────┘   │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  ┌──────────────┐         ┌──────────────┐        ┌──────────────┐    │
│  │  DynamoDB    │         │ EventBridge  │        │   SQS Queue  │    │
│  │              │◄────────┤              ├───────►│              │    │
│  │  Todo Table  │         │  (Spot Int.) │        │  (Karpenter) │    │
│  └──────────────┘         └──────────────┘        └──────────────┘    │
│                                                                          │
│  ┌──────────────┐         ┌──────────────┐        ┌──────────────┐    │
│  │     ECR      │         │     IAM      │        │  CloudWatch  │    │
│  │              │         │  (IRSA or    │        │              │    │
│  │ Docker Images│         │ Pod Identity)│        │   Logs       │    │
│  └──────────────┘         └──────────────┘        └──────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
```

### Component Flow

1. **User Request**: Client sends request to ALB
2. **Load Balancing**: ALB routes traffic to appropriate service (Frontend/Backend)
3. **Frontend**: React app serves UI, makes API calls to Backend
4. **Backend**: Django REST API processes requests, interacts with DynamoDB
5. **Database**: DynamoDB stores todo items with automatic scaling
6. **Auto-scaling**: Karpenter provisions nodes based on pod requirements
7. **Interruption Handling**: EventBridge → SQS → Karpenter for spot instance management

## Features

### Application Features
- **CRUD Operations**: Create, Read, Update, Delete todos
- **Real-time Updates**: Instant UI updates on state changes
- **Responsive Design**: Beautiful UI with Tailwind CSS
- **Error Handling**: Comprehensive error messages and recovery
- **Health Checks**: Backend and frontend health monitoring
- **Persistent Storage**: DynamoDB for reliable data storage

### Infrastructure Features
- **Kubernetes Orchestration**: EKS cluster with managed node groups
- **Auto-scaling**: Horizontal Pod Autoscaler (HPA) + Karpenter
- **Security**: IRSA or Pod Identity, Security Groups, Network Policies
- **Observability**: CloudWatch logs and metrics
- **Cost Optimization**: Spot instances with Karpenter
- **High Availability**: Multi-AZ deployment
- **Fault Tolerance**: Automatic node replacement
- **Containerization**: Docker containers for both frontend and backend

### DevOps Features
- **Infrastructure as Code**: Complete Terraform automation
- **GitOps Ready**: Declarative Kubernetes manifests
- **CI/CD Ready**: Automated build and deployment scripts
- **Documentation**: Comprehensive guides and runbooks
- **Testing**: Health check endpoints and monitoring

## Technology Stack

### Frontend
- **Framework**: React 18.2 with Hooks
- **Build Tool**: Vite 5.0
- **Styling**: Tailwind CSS 3.4
- **HTTP Client**: Axios 1.6
- **Icons**: Lucide React
- **Server**: Nginx (Production)

### Backend
- **Framework**: Django 5.0 + Django REST Framework 3.14
- **WSGI Server**: Gunicorn 21.2
- **Static Files**: WhiteNoise 6.6
- **Database Client**: Boto3 1.34
- **CORS**: django-cors-headers 4.3
- **Configuration**: python-decouple 3.8

### Infrastructure
- **Container Orchestration**: Amazon EKS 1.28
- **Auto-scaling**: Karpenter v0.33.0
- **Database**: Amazon DynamoDB (Serverless)
- **Load Balancer**: AWS Application Load Balancer
- **Infrastructure as Code**: Terraform 1.0+
- **Networking**: VPC with public/private subnets across 3 AZs
- **DNS**: Route53 (optional)
- **Certificate Management**: AWS Certificate Manager (optional)

### Observability
- **Logging**: CloudWatch Logs
- **Metrics**: CloudWatch Metrics + Prometheus (optional)
- **Monitoring**: CloudWatch Container Insights
- **Alerting**: CloudWatch Alarms

## Pod Authentication Modes

This project supports **two authentication methods** for pods to access AWS services:

### Authentication Options

| Method | Status | When to Use |
|--------|--------|-------------|
| **IRSA** (IAM Roles for Service Accounts) | Default | Existing clusters, maximum compatibility |
| **Pod Identity** (EKS Pod Identity) | Modern (2023) | New clusters, simpler setup |

### Quick Comparison

- **IRSA** (2019): Traditional, requires OIDC provider, widely documented
- **Pod Identity** (2023): Simpler setup, faster credentials (5 min vs 15 min), no OIDC needed

### Configuration

Set in `terraform/terraform.tfvars`:

```hcl
# For IRSA (default)
pod_authentication_mode = "irsa"

# For Pod Identity (newer, simpler)
pod_authentication_mode = "pod-identity"
```

### Detailed Documentation

See [docs/pod-authentication-modes.md](docs/pod-authentication-modes.md) for:
- Detailed architecture comparison
- Trust policy differences
- Migration guide between modes
- Troubleshooting tips
- Performance considerations

## Prerequisites

### Required Tools
- **AWS CLI** (v2.0+) - [Install Guide](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
- **Terraform** (v1.0+) - [Install Guide](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- **kubectl** (v1.28+) - [Install Guide](https://kubernetes.io/docs/tasks/tools/)
- **Helm** (v3.0+) - [Install Guide](https://helm.sh/docs/intro/install/)
- **Docker** (v20.0+) - [Install Guide](https://docs.docker.com/get-docker/)
- **Git** (v2.0+)

### Optional Tools
- **eksctl** - For simplified EKS operations
- **k9s** - Terminal UI for Kubernetes
- **lens** - Kubernetes IDE

### AWS Requirements
- **AWS Account** with administrative access
- **AWS Credentials** configured (`~/.aws/credentials` or environment variables)
- **IAM Permissions** for:
  - EKS cluster creation and management
  - VPC and networking resources
  - EC2 instances
  - DynamoDB tables
  - IAM roles and policies
  - CloudWatch logs
  - SQS queues
  - EventBridge rules

### Cost Considerations
Estimated monthly costs (us-east-1):
- EKS Control Plane: ~$73
- EC2 Instances (2x t3.medium): ~$60
- NAT Gateways (3): ~$100
- DynamoDB: Pay-per-request (varies)
- Data Transfer: Varies
- **Total: ~$233/month + usage-based costs**

Using Karpenter with spot instances can reduce costs by up to 70%.

## Quick Start

Get the application running in under 30 minutes:

```bash
# 1. Clone the repository
git clone https://github.com/d-padmanabhan/aws-eks-karpenter.git
cd aws-eks-karpenter

# 2. Configure AWS credentials
aws configure

# 3. Deploy infrastructure
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform apply

# 4. Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name todo-app-cluster

# 5. Install Karpenter (optional but recommended)
cd ../k8s/karpenter
./install-karpenter.sh

# 6. Build and push Docker images
# Set your ECR repository or Docker Hub username
export DOCKER_REGISTRY=<your-registry>
cd ../../
./scripts/build-and-push.sh

# 7. Deploy application
./scripts/deploy-app.sh

# 8. Get application URL
kubectl get ingress -n todo-app
```

## Detailed Setup

### Step 1: Infrastructure Deployment

#### 1.1 Configure Terraform Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
aws_region          = "us-east-1"
cluster_name        = "todo-app-cluster"
cluster_version     = "1.28"
vpc_cidr            = "10.0.0.0/16"
dynamodb_table_name = "todo-app-table"
node_instance_types = ["t3.medium"]
node_desired_size   = 2
node_min_size       = 1
node_max_size       = 4
environment         = "production"
```

#### 1.2 Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Apply infrastructure
terraform apply

# Save outputs
terraform output > ../outputs.txt
```

This creates:
- VPC with 3 public and 3 private subnets
- NAT Gateways for internet access
- EKS cluster with managed node group
- DynamoDB table
- IAM roles for IRSA and Karpenter
- SQS queue for Karpenter interruption handling
- EventBridge rules for spot instance events

#### 1.3 Configure kubectl

```bash
aws eks update-kubeconfig --region us-east-1 --name todo-app-cluster
kubectl get nodes
```

### Step 2: Install AWS Load Balancer Controller

```bash
# Create IAM policy
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.6.2/docs/install/iam_policy.json

aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json

# Get your AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create service account
eksctl create iamserviceaccount \
  --cluster=todo-app-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy \
  --override-existing-serviceaccounts \
  --approve

# Install via Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=todo-app-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# Verify installation
kubectl get deployment -n kube-system aws-load-balancer-controller
```

### Step 3: Install Karpenter (Recommended)

Karpenter provides efficient, cost-optimized auto-scaling:

```bash
cd k8s/karpenter
./install-karpenter.sh

# Verify installation
kubectl get pods -n karpenter
kubectl get nodepool
kubectl get ec2nodeclass
```

See [Karpenter Documentation](k8s/karpenter/README.md) for detailed configuration.

### Step 4: Build and Push Docker Images

#### 4.1 Setup Container Registry

**Option A: Amazon ECR**
```bash
# Create ECR repositories
aws ecr create-repository --repository-name todo-backend --region us-east-1
aws ecr create-repository --repository-name todo-frontend --region us-east-1

# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com

export DOCKER_REGISTRY=${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com
```

**Option B: Docker Hub**
```bash
docker login
export DOCKER_REGISTRY=your-dockerhub-username
```

#### 4.2 Build and Push

```bash
# Backend
cd backend
docker build -t ${DOCKER_REGISTRY}/todo-backend:latest .
docker push ${DOCKER_REGISTRY}/todo-backend:latest

# Frontend
cd ../frontend
docker build -t ${DOCKER_REGISTRY}/todo-frontend:latest .
docker push ${DOCKER_REGISTRY}/todo-frontend:latest
```

Or use the automated script:
```bash
./scripts/build-and-push.sh
```

### Step 5: Deploy Application

#### 5.1 Update Kubernetes Manifests

**Update Backend Service Account** (`k8s/backend/serviceaccount.yaml`):
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backend-sa
  namespace: todo-app
  annotations:
    eks.amazonaws.com/role-arn: <IRSA_ROLE_ARN_FROM_TERRAFORM_OUTPUT>
```

**Update Deployments** with your Docker registry:
- `k8s/backend/deployment.yaml`
- `k8s/frontend/deployment.yaml`

```yaml
image: ${DOCKER_REGISTRY}/todo-backend:latest
image: ${DOCKER_REGISTRY}/todo-frontend:latest
```

#### 5.2 Deploy Resources

```bash
# Create namespace
kubectl apply -f k8s/namespace.yaml

# Deploy backend
kubectl apply -f k8s/backend/

# Deploy frontend
kubectl apply -f k8s/frontend/

# Deploy ingress
kubectl apply -f k8s/ingress.yaml

# Verify deployment
kubectl get pods -n todo-app
kubectl get svc -n todo-app
kubectl get ingress -n todo-app
```

Or use the automated script:
```bash
./scripts/deploy-app.sh
```

#### 5.3 Access the Application

```bash
# Get ALB URL
ALB_URL=$(kubectl get ingress todo-app-ingress -n todo-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Application URL: http://${ALB_URL}"

# Test backend health
curl http://${ALB_URL}/api/health/

# Open in browser
open http://${ALB_URL}
```

## Project Structure

```
aws-eks-karpenter/
├── backend/                      # Django backend application
│   ├── todos/                    # Todo app
│   │   ├── __init__.py
│   │   ├── apps.py
│   │   ├── dynamodb.py          # DynamoDB client
│   │   ├── serializers.py       # DRF serializers
│   │   ├── urls.py              # URL routing
│   │   └── views.py             # API views
│   ├── todo_project/            # Django project settings
│   │   ├── __init__.py
│   │   ├── asgi.py
│   │   ├── settings.py          # Django settings
│   │   ├── urls.py              # Main URL config
│   │   └── wsgi.py
│   ├── .dockerignore
│   ├── .env.example             # Environment variables template
│   ├── Dockerfile               # Backend container
│   ├── manage.py
│   └── requirements.txt         # Python dependencies
├── frontend/                     # React frontend application
│   ├── src/
│   │   ├── api/
│   │   │   └── todoApi.js       # API client
│   │   ├── App.jsx              # Main React component
│   │   ├── index.css            # Tailwind styles
│   │   └── main.jsx             # Entry point
│   ├── .dockerignore
│   ├── .env.example             # Environment variables template
│   ├── Dockerfile               # Frontend container
│   ├── index.html
│   ├── nginx.conf               # Nginx configuration
│   ├── package.json
│   ├── postcss.config.js
│   ├── tailwind.config.js       # Tailwind configuration
│   └── vite.config.js           # Vite configuration
├── terraform/                    # Infrastructure as Code
│   ├── dynamodb.tf              # DynamoDB table
│   ├── eks.tf                   # EKS cluster and IRSA
│   ├── karpenter.tf             # Karpenter resources
│   ├── main.tf                  # Provider configuration
│   ├── outputs.tf               # Terraform outputs
│   ├── variables.tf             # Variable definitions
│   ├── vpc.tf                   # VPC and networking
│   ├── .gitignore
│   ├── README.md
│   └── terraform.tfvars.example # Variables template
├── k8s/                          # Kubernetes manifests
│   ├── backend/
│   │   ├── configmap.yaml       # Backend config
│   │   ├── deployment.yaml      # Backend deployment
│   │   ├── hpa.yaml             # Horizontal Pod Autoscaler
│   │   ├── secret.yaml          # Secrets (Django secret key)
│   │   ├── service.yaml         # Backend service
│   │   └── serviceaccount.yaml  # IRSA service account
│   ├── frontend/
│   │   ├── configmap.yaml       # Frontend config
│   │   ├── deployment.yaml      # Frontend deployment
│   │   ├── hpa.yaml             # Horizontal Pod Autoscaler
│   │   └── service.yaml         # Frontend service
│   ├── karpenter/
│   │   ├── install-karpenter.sh # Installation script
│   │   ├── namespace.yaml       # Karpenter namespace
│   │   ├── nodepool.yaml        # NodePool configuration
│   │   ├── README.md            # Karpenter documentation
│   │   └── serviceaccount.yaml  # Karpenter service account
│   ├── aws-load-balancer-controller.yaml
│   ├── ingress.yaml             # ALB ingress
│   ├── namespace.yaml           # Application namespace
│   └── README.md
├── scripts/                      # Automation scripts
│   ├── build-and-push.sh        # Build and push Docker images
│   ├── cleanup.sh               # Resource cleanup
│   ├── deploy-app.sh            # Deploy application
│   ├── deploy-infrastructure.sh # Deploy infrastructure
│   └── local-dev.sh             # Local development setup
├── .gitignore
└── README.md                     # This file
```

## Infrastructure

### VPC Architecture

The VPC is configured with:
- **CIDR**: 10.0.0.0/16
- **Availability Zones**: 3 AZs for high availability
- **Public Subnets**: 3 subnets for NAT Gateways and ALB
- **Private Subnets**: 3 subnets for EKS nodes
- **NAT Gateways**: 3 (one per AZ) for outbound internet access
- **Internet Gateway**: For public subnet internet access

### EKS Cluster

- **Version**: 1.28 (configurable)
- **Node Groups**: Managed node group with 1-4 nodes
- **Instance Types**: t3.medium (configurable)
- **Addons**:
  - CoreDNS
  - kube-proxy
  - VPC CNI
  - EBS CSI Driver

### DynamoDB Table

- **Billing Mode**: PAY_PER_REQUEST (on-demand)
- **Partition Key**: `id` (String)
- **Features**:
  - Point-in-time recovery enabled
  - Encryption at rest enabled
  - Auto-scaling (managed by AWS)

### IAM Roles

1. **Backend IRSA Role**: Allows backend pods to access DynamoDB
2. **Karpenter Controller Role**: Allows Karpenter to provision EC2 instances
3. **Karpenter Node Role**: Attached to nodes provisioned by Karpenter

## Karpenter Auto-Scaling

Karpenter is a flexible, high-performance Kubernetes cluster autoscaler that automatically provisions right-sized compute resources.

### Why Karpenter?

- **Faster Scaling**: Provisions nodes in seconds, not minutes
- **Cost Optimization**: Automatically selects the most cost-effective instance types
- **Bin Packing**: Efficiently packs pods onto nodes
- **Spot Instance Support**: Seamlessly handles spot interruptions
- **Flexible Configuration**: Fine-grained control over node provisioning

### NodePool Configuration

```yaml
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: default
spec:
  template:
    spec:
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand", "spot"]  # 50/50 mix
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["t", "c", "m", "r"]    # General purpose, compute, memory
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["2"]                    # Only modern instances
  limits:
    cpu: "100"
    memory: 200Gi
  disruption:
    consolidationPolicy: WhenUnderutilized
    consolidateAfter: 30s
```

### Interruption Handling

Karpenter automatically handles spot instance interruptions:

```
EventBridge → SQS Queue → Karpenter Controller
    ↓
Cordon Node → Drain Pods → Provision Replacement → Terminate Node
```

See [Karpenter README](k8s/karpenter/README.md) for detailed documentation.

## Deployment

### Deployment Strategies

#### 1. Manual Deployment
```bash
kubectl apply -f k8s/
```

#### 2. Scripted Deployment
```bash
./scripts/deploy-app.sh
```

#### 3. GitOps (ArgoCD/Flux)
```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Create application
argocd app create todo-app \
  --repo https://github.com/d-padmanabhan/aws-eks-karpenter \
  --path k8s \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace todo-app
```

### Rolling Updates

```bash
# Update image tag
kubectl set image deployment/backend backend=${DOCKER_REGISTRY}/todo-backend:v2 -n todo-app
kubectl set image deployment/frontend frontend=${DOCKER_REGISTRY}/todo-frontend:v2 -n todo-app

# Monitor rollout
kubectl rollout status deployment/backend -n todo-app
kubectl rollout status deployment/frontend -n todo-app

# Rollback if needed
kubectl rollout undo deployment/backend -n todo-app
```

### Blue-Green Deployment

```bash
# Deploy new version with different label
kubectl apply -f k8s/backend/deployment-v2.yaml

# Test new version
kubectl port-forward deployment/backend-v2 8000:8000 -n todo-app

# Switch traffic
kubectl patch service backend -n todo-app -p '{"spec":{"selector":{"version":"v2"}}}'

# Remove old version
kubectl delete deployment backend-v1 -n todo-app
```

## Monitoring & Operations

### Health Checks

```bash
# Backend health
curl http://${ALB_URL}/api/health/

# Frontend health (via ALB)
curl http://${ALB_URL}/

# Kubernetes health
kubectl get pods -n todo-app
kubectl get nodes
```

### View Logs

```bash
# Backend logs
kubectl logs -f deployment/backend -n todo-app

# Frontend logs
kubectl logs -f deployment/frontend -n todo-app

# Karpenter logs
kubectl logs -f -n karpenter -l app.kubernetes.io/name=karpenter

# CloudWatch Logs
aws logs tail /aws/eks/todo-app-cluster/cluster --follow
```

### Metrics

```bash
# Pod metrics
kubectl top pods -n todo-app

# Node metrics
kubectl top nodes

# HPA status
kubectl get hpa -n todo-app

# Karpenter metrics
kubectl get nodepool
kubectl describe nodepool default
```

### CloudWatch Container Insights

```bash
# Install Container Insights
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluentd-quickstart.yaml

# View in CloudWatch Console
# Navigate to CloudWatch → Container Insights → Performance monitoring
```

## Security

### Network Security

- **Private Subnets**: EKS nodes are in private subnets with no direct internet access
- **Security Groups**: Restrictive security group rules for cluster and node communication
- **Network Policies**: Pod-to-pod communication restrictions (optional)

### IAM Security

- **IRSA**: IAM Roles for Service Accounts for least-privilege access
- **No Hardcoded Credentials**: All AWS access via IRSA
- **Separate Roles**: Different roles for backend, Karpenter controller, and Karpenter nodes

### Application Security

- **Secrets Management**: Kubernetes Secrets for sensitive data
- **HTTPS**: SSL/TLS with AWS Certificate Manager (optional)
- **CORS**: Configured CORS policies
- **Django Security**:
  - Secret key stored in Kubernetes Secret
  - Security headers enabled in production
  - Debug mode disabled in production

### Best Practices

1. **Enable GuardDuty**: AWS threat detection
2. **Enable AWS WAF**: Web application firewall on ALB
3. **Use Secrets Manager**: For production secrets
4. **Implement Network Policies**: Restrict pod communication
5. **Regular Updates**: Keep dependencies and images updated
6. **Audit Logging**: Enable CloudTrail and EKS audit logs

## Cost Optimization

### Karpenter Savings

- **Spot Instances**: Up to 90% savings vs On-Demand
- **Right-sizing**: Automatically selects optimal instance types
- **Consolidation**: Removes underutilized nodes
- **Bin Packing**: Efficiently uses node resources

### Other Optimizations

```bash
# Use Spot instances in NodePool (already configured)
# Adjust node limits based on actual usage
# Use S3 for static assets instead of EBS
# Enable DynamoDB auto-scaling with limits
# Use CloudFront CDN for frontend assets
```

### Cost Monitoring

```bash
# Tag resources for cost allocation
# Already configured in Terraform:
# - Project: todo-app
# - Environment: production
# - ManagedBy: terraform

# Use AWS Cost Explorer with these tags
# Set up billing alerts
aws cloudwatch put-metric-alarm \
  --alarm-name high-cost-alert \
  --alarm-description "Alert when cost exceeds $300/month" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 21600 \
  --evaluation-periods 1 \
  --threshold 300 \
  --comparison-operator GreaterThanThreshold
```

## Troubleshooting

### Common Issues

#### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n todo-app
kubectl describe pod <pod-name> -n todo-app

# Common causes:
# 1. Image pull errors (check registry credentials)
# 2. Insufficient resources (check node capacity)
# 3. Configuration errors (check ConfigMaps/Secrets)
```

#### Backend Can't Access DynamoDB

```bash
# Verify IRSA configuration
kubectl get sa backend-sa -n todo-app -o yaml

# Check IAM role
aws iam get-role --role-name todo-app-cluster-backend-irsa

# Verify credentials in pod
kubectl exec -it <backend-pod> -n todo-app -- env | grep AWS
```

#### ALB Not Creating

```bash
# Check AWS Load Balancer Controller
kubectl get deployment -n kube-system aws-load-balancer-controller

# View controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Verify ingress
kubectl describe ingress todo-app-ingress -n todo-app
```

#### Karpenter Not Provisioning Nodes

```bash
# Check Karpenter logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter

# Verify NodePool
kubectl describe nodepool default

# Check IAM permissions
aws iam get-role --role-name todo-app-cluster-karpenter-controller

# Verify subnet and security group tags
aws ec2 describe-subnets --filters "Name=tag:karpenter.sh/discovery,Values=todo-app-cluster"
```

### Debug Commands

```bash
# Port forward to backend
kubectl port-forward deployment/backend 8000:8000 -n todo-app

# Port forward to frontend
kubectl port-forward deployment/frontend 80:80 -n todo-app

# Execute shell in pod
kubectl exec -it <pod-name> -n todo-app -- /bin/bash

# View events
kubectl get events -n todo-app --sort-by='.lastTimestamp'

# Check resource usage
kubectl top pods -n todo-app
kubectl top nodes
```

## CI/CD

### GitHub Actions Example

```yaml
name: Deploy to EKS

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@main
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@main
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      
      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@main
      
      - name: Build and push backend
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
        run: |
          cd backend
          docker build -t $ECR_REGISTRY/todo-backend:${{ github.sha }} .
          docker push $ECR_REGISTRY/todo-backend:${{ github.sha }}
      
      - name: Build and push frontend
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
        run: |
          cd frontend
          docker build -t $ECR_REGISTRY/todo-frontend:${{ github.sha }} .
          docker push $ECR_REGISTRY/todo-frontend:${{ github.sha }}
      
      - name: Update kube config
        run: aws eks update-kubeconfig --name todo-app-cluster --region us-east-1
      
      - name: Deploy to EKS
        run: |
          kubectl set image deployment/backend backend=$ECR_REGISTRY/todo-backend:${{ github.sha }} -n todo-app
          kubectl set image deployment/frontend frontend=$ECR_REGISTRY/todo-frontend:${{ github.sha }} -n todo-app
```

## Cleanup

### Delete Application

```bash
# Delete application resources
kubectl delete -f k8s/ingress.yaml
kubectl delete -f k8s/frontend/
kubectl delete -f k8s/backend/
kubectl delete namespace todo-app

# Uninstall Karpenter
helm uninstall karpenter -n karpenter
kubectl delete namespace karpenter

# Uninstall AWS Load Balancer Controller
helm uninstall aws-load-balancer-controller -n kube-system
```

### Destroy Infrastructure

```bash
cd terraform
terraform destroy

# Or use the cleanup script
./scripts/cleanup.sh
```

**Note**: This will delete all resources including the DynamoDB table and all data.

## Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Setup

```bash
# Clone repository
git clone https://github.com/d-padmanabhan/aws-eks-karpenter.git
cd aws-eks-karpenter

# Backend development
cd backend
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
python manage.py runserver

# Frontend development
cd frontend
npm install
npm run dev
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
