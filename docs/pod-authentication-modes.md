# Pod Authentication Modes: IRSA vs Pod Identity

This project supports **two authentication methods** for pods to access AWS services:

1. **IRSA** (IAM Roles for Service Accounts) - Traditional, battle-tested
2. **Pod Identity** (EKS Pod Identity) - Modern, simpler (GA since 2023)

## Quick Comparison

| Feature | IRSA | Pod Identity |
|---------|------|--------------|
| **Launch Date** | 2019 | 2023 (GA) |
| **Maturity** | Production-ready for 5+ years | Production-ready since 2023 |
| **Setup Complexity** | Medium (requires OIDC) | **Simpler** |
| **Trust Policy** | Complex OIDC conditions | **Simple service principal** |
| **ServiceAccount Annotation** | Required | **Not needed** |
| **Credential Rotation** | Every 15 minutes | **Every 5 minutes** |
| **Regional Support** | All AWS regions | Most regions (check availability) |
| **AWS API Call** | `AssumeRoleWithWebIdentity` | `AssumeRoleForPodIdentity` |
| **Prerequisites** | OIDC provider enabled | **Pod Identity Agent addon** |
| **Recommended For** | Existing clusters, maximum compatibility | **New clusters, simpler setup** |

## How to Choose

### Choose IRSA if:
- You have an existing cluster with IRSA already configured
- You need maximum regional availability
- You prefer the battle-tested, widely-documented solution
- Your team is already familiar with OIDC-based authentication

### Choose Pod Identity if:
- You're deploying a new cluster
- You want simpler IAM configuration (no OIDC setup)
- You want faster credential rotation (5 min vs 15 min)
- You're experiencing STS API throttling issues
- You want to demonstrate modern AWS best practices

## Configuration

### Setting the Authentication Mode

Edit `terraform/terraform.tfvars`:

```hcl
# For IRSA (default)
pod_authentication_mode = "irsa"

# For Pod Identity
pod_authentication_mode = "pod-identity"
```

## Architecture Differences

### IRSA Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ EKS Cluster                                                 │
│                                                             │
│  ┌──────────────────┐         ┌─────────────────────────┐  │
│  │  Backend Pod     │         │  OIDC Provider          │  │
│  │  ┌────────────┐  │         │  (*.eks.amazonaws.com)  │  │
│  │  │ Container  │  │         └──────────┬──────────────┘  │
│  │  └────────────┘  │                    │                 │
│  │                  │                    │                 │
│  │  ServiceAccount  │                    │                 │
│  │  with annotation │                    │                 │
│  └─────┬────────────┘                    │                 │
│        │                                 │                 │
└────────┼─────────────────────────────────┼─────────────────┘
         │                                 │
         │ 1. Get OIDC token               │
         │                                 │
         ▼                                 ▼
    ┌─────────────────────────────────────────────┐
    │ AWS STS                                      │
    │ AssumeRoleWithWebIdentity                    │
    │                                              │
    │ Validates OIDC token against:                │
    │ - OIDC provider thumbprint                   │
    │ - Service account name                       │
    │ - Namespace                                  │
    └─────────────────┬────────────────────────────┘
                      │
                      │ 2. Returns temporary credentials
                      ▼
              ┌──────────────────┐
              │  IAM Role        │
              │  (with DynamoDB  │
              │   permissions)   │
              └──────────────────┘
```

**Key Components:**
- OIDC provider must be created for the cluster
- ServiceAccount needs annotation: `eks.amazonaws.com/role-arn`
- IAM role trust policy must reference OIDC provider ARN
- Complex trust policy with conditions

### Pod Identity Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ EKS Cluster                                                 │
│                                                             │
│  ┌──────────────────┐         ┌─────────────────────────┐  │
│  │  Backend Pod     │         │  Pod Identity Agent     │  │
│  │  ┌────────────┐  │         │  (EKS Addon)            │  │
│  │  │ Container  │  │         └──────────┬──────────────┘  │
│  │  └────────────┘  │                    │                 │
│  │                  │                    │                 │
│  │  ServiceAccount  │                    │                 │
│  │  (no annotation) │                    │                 │
│  └─────┬────────────┘                    │                 │
│        │                                 │                 │
└────────┼─────────────────────────────────┼─────────────────┘
         │                                 │
         │ 1. Pod Identity Agent handles   │
         │    credential retrieval         │
         │                                 │
         ▼                                 ▼
    ┌─────────────────────────────────────────────┐
    │ AWS EKS Pod Identity Service                 │
    │ AssumeRoleForPodIdentity                     │
    │                                              │
    │ Uses Pod Identity Association to map:        │
    │ - Namespace + ServiceAccount → IAM Role      │
    └─────────────────┬────────────────────────────┘
                      │
                      │ 2. Returns temporary credentials
                      ▼
              ┌──────────────────┐
              │  IAM Role        │
              │  (with DynamoDB  │
              │   permissions)   │
              └──────────────────┘
```

**Key Components:**
- Pod Identity Agent addon (installed automatically by Terraform)
- ServiceAccount needs **NO annotations**
- IAM role trust policy is simple: trust `pods.eks.amazonaws.com`
- Pod Identity Association resource maps namespace+SA to IAM role

## ServiceAccount Configuration

### For IRSA Mode

Uncomment the annotation in `k8s/backend/serviceaccount.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backend-sa
  namespace: todo-app
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/todo-app-cluster-backend-irsa
```

### For Pod Identity Mode

No annotations needed! Just use the basic ServiceAccount:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backend-sa
  namespace: todo-app
  # No annotations - association handled by Terraform!
```

## IAM Role Trust Policies

### IRSA Trust Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE:sub": "system:serviceaccount:todo-app:backend-sa",
          "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
```

### Pod Identity Trust Policy (Simpler!)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "pods.eks.amazonaws.com"
      },
      "Action": [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }
  ]
}
```

## Terraform Resources Created

### IRSA Mode
- OIDC provider enabled on EKS cluster
- IAM role with OIDC-based trust policy
- IAM policy with DynamoDB permissions
- Role-policy attachment

### Pod Identity Mode
- Pod Identity Agent addon installed
- IAM role with simple service principal trust policy
- IAM policy with DynamoDB permissions
- Role-policy attachment
- **Pod Identity Association** (maps namespace+SA to role)

## Migration Guide

### From IRSA to Pod Identity

1. **Update Terraform configuration:**
   ```hcl
   pod_authentication_mode = "pod-identity"
   ```

2. **Apply Terraform changes:**
   ```bash
   terraform apply
   ```

3. **Update ServiceAccount (remove annotation):**
   ```bash
   kubectl annotate serviceaccount backend-sa \
     eks.amazonaws.com/role-arn- \
     -n todo-app
   ```

4. **Restart pods to pick up new credentials:**
   ```bash
   kubectl rollout restart deployment/backend -n todo-app
   ```

### From Pod Identity to IRSA

1. **Update Terraform configuration:**
   ```hcl
   pod_authentication_mode = "irsa"
   ```

2. **Apply Terraform changes:**
   ```bash
   terraform apply
   ```

3. **Get the new IRSA role ARN:**
   ```bash
   terraform output backend_role_arn
   ```

4. **Update ServiceAccount (add annotation):**
   ```bash
   kubectl annotate serviceaccount backend-sa \
     eks.amazonaws.com/role-arn=<ROLE_ARN> \
     -n todo-app
   ```

5. **Restart pods:**
   ```bash
   kubectl rollout restart deployment/backend -n todo-app
   ```

## Troubleshooting

### IRSA Issues

**Problem:** Pods can't assume IAM role

**Check:**
```bash
# 1. Verify OIDC provider exists
aws eks describe-cluster --name todo-app-cluster \
  --query "cluster.identity.oidc.issuer" --output text

# 2. Verify ServiceAccount annotation
kubectl get sa backend-sa -n todo-app -o yaml | grep role-arn

# 3. Check pod logs
kubectl logs -n todo-app -l app=backend
```

### Pod Identity Issues

**Problem:** Pods can't assume IAM role

**Check:**
```bash
# 1. Verify Pod Identity Agent is running
kubectl get pods -n kube-system -l app.kubernetes.io/name=eks-pod-identity-agent

# 2. Verify Pod Identity Association exists
aws eks list-pod-identity-associations --cluster-name todo-app-cluster

# 3. Describe the association
aws eks describe-pod-identity-association \
  --cluster-name todo-app-cluster \
  --association-id <ASSOCIATION_ID>

# 4. Check pod logs
kubectl logs -n todo-app -l app=backend
```

## Performance Considerations

### Credential Rotation
- **IRSA:** Credentials rotate every 15 minutes
- **Pod Identity:** Credentials rotate every 5 minutes (faster!)

### STS API Throttling
- **IRSA:** Each pod makes `AssumeRoleWithWebIdentity` calls
- **Pod Identity:** More efficient credential caching by the agent

For clusters with **many pods** (100+), Pod Identity can significantly reduce STS API throttling.

## Security Considerations

### Both methods provide:
- No hardcoded credentials in code or containers
- Temporary credentials that auto-rotate
- Least-privilege access (IAM policies)
- Audit trail in CloudTrail

### IRSA specific:
- Trust policy explicitly validates namespace and ServiceAccount name
- OIDC provider thumbprint validation

### Pod Identity specific:
- Association managed by AWS control plane
- Simpler trust policy (fewer misconfiguration risks)
- Centralized management via EKS APIs

## Cost Implications

Both methods have **no additional AWS costs** beyond standard AWS API calls:
- STS API calls (free tier: 1,000 API calls/month)
- CloudTrail logs (if enabled)

## References

- [AWS Documentation: IAM Roles for Service Accounts](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [AWS Documentation: EKS Pod Identity](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html)
- [AWS Blog: Introducing Amazon EKS Pod Identity](https://aws.amazon.com/blogs/aws/amazon-eks-pod-identity-simplifies-iam-permissions-for-applications-on-amazon-eks-clusters/)
- [Terraform: aws_eks_pod_identity_association](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_pod_identity_association)
