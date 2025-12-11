# Terraform Infrastructure

This directory contains Terraform configuration for deploying the Todo App infrastructure on AWS.

## Architecture

- **VPC**: Multi-AZ VPC with public and private subnets
- **EKS**: Managed Kubernetes cluster with managed node groups
- **DynamoDB**: Serverless NoSQL database for todo storage
- **IRSA**: IAM Roles for Service Accounts for secure AWS access

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- kubectl

## Deployment Steps

### 1. Initialize Terraform

```bash
cd terraform
terraform init
```

### 2. Configure Variables

Copy the example variables file and customize:

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 3. Plan Infrastructure

```bash
terraform plan
```

### 4. Apply Infrastructure

```bash
terraform apply
```

This will create:
- VPC with 3 public and 3 private subnets across 3 AZs
- NAT Gateways for private subnet internet access
- EKS cluster with managed node group
- DynamoDB table for todos
- IAM roles and policies for service accounts

### 5. Configure kubectl

After the cluster is created, configure kubectl:

```bash
aws eks update-kubeconfig --region us-east-1 --name todo-app-cluster
```

Verify cluster access:

```bash
kubectl get nodes
```

## Resources Created

### Networking
- 1 VPC
- 3 Public Subnets
- 3 Private Subnets
- 3 NAT Gateways
- Internet Gateway
- Route Tables

### Compute
- EKS Control Plane
- EKS Managed Node Group (2-4 t3.medium instances)
- Security Groups

### Storage
- DynamoDB Table (PAY_PER_REQUEST billing)

### IAM
- EKS Cluster Role
- Node Group Role
- IRSA Role for Backend Pods
- DynamoDB Access Policy

## Outputs

After applying, Terraform will output:
- Cluster name and endpoint
- VPC and subnet IDs
- DynamoDB table name
- Backend IRSA role ARN
- kubectl configuration command

## Cost Estimation

Approximate monthly costs (us-east-1):
- EKS Control Plane: ~$73
- EC2 Instances (2x t3.medium): ~$60
- NAT Gateways (3): ~$100
- DynamoDB: Pay-per-request (varies)
- Data Transfer: Varies

**Total: ~$233/month + usage-based costs**

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Warning**: This will delete all resources including the DynamoDB table and all data.

## Security Considerations

- EKS cluster endpoint is public (can be restricted to specific IPs)
- Nodes are in private subnets
- IRSA is used for secure AWS service access
- DynamoDB encryption at rest is enabled
- Point-in-time recovery is enabled for DynamoDB

## Customization

Edit `variables.tf` or `terraform.tfvars` to customize:
- AWS region
- Instance types
- Node group size
- VPC CIDR ranges
- Cluster version
