# Kubernetes Manifests

This directory contains Kubernetes manifests for deploying the Todo App on EKS.

## Prerequisites

- EKS cluster running (created via Terraform)
- kubectl configured to access the cluster
- AWS Load Balancer Controller installed
- Docker images built and pushed to a registry

## Directory Structure

```
k8s/
├── namespace.yaml                    # Application namespace
├── backend/
│   ├── serviceaccount.yaml          # Service account with IRSA
│   ├── configmap.yaml               # Backend configuration
│   ├── secret.yaml                  # Sensitive data (Django secret)
│   ├── deployment.yaml              # Backend deployment
│   ├── service.yaml                 # Backend service
│   └── hpa.yaml                     # Horizontal Pod Autoscaler
├── frontend/
│   ├── configmap.yaml               # Frontend configuration
│   ├── deployment.yaml              # Frontend deployment
│   ├── service.yaml                 # Frontend service
│   └── hpa.yaml                     # Horizontal Pod Autoscaler
├── ingress.yaml                     # ALB Ingress
└── aws-load-balancer-controller.yaml # Controller setup instructions
```

## Deployment Steps

### 1. Install AWS Load Balancer Controller

```bash
# Download IAM policy
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.6.2/docs/install/iam_policy.json

# Create IAM policy
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json

# Create service account with IRSA
eksctl create iamserviceaccount \
  --cluster=todo-app-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
  --override-existing-serviceaccounts \
  --approve

# Install controller via Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=todo-app-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# Verify
kubectl get deployment -n kube-system aws-load-balancer-controller
```

### 2. Update Configuration

Before deploying, update the following:

**backend/serviceaccount.yaml**:
```yaml
eks.amazonaws.com/role-arn: <IRSA_ROLE_ARN_FROM_TERRAFORM>
```

**backend/secret.yaml**:
```bash
# Generate a secure Django secret key
python -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())'
```

**backend/deployment.yaml** and **frontend/deployment.yaml**:
```yaml
image: YOUR_REGISTRY/todo-backend:latest
image: YOUR_REGISTRY/todo-frontend:latest
```

### 3. Build and Push Docker Images

```bash
# Backend
cd backend
docker build -t YOUR_REGISTRY/todo-backend:latest .
docker push YOUR_REGISTRY/todo-backend:latest

# Frontend
cd frontend
docker build -t YOUR_REGISTRY/todo-frontend:latest .
docker push YOUR_REGISTRY/todo-frontend:latest
```

### 4. Deploy Application

```bash
# Create namespace
kubectl apply -f namespace.yaml

# Deploy backend
kubectl apply -f backend/

# Deploy frontend
kubectl apply -f frontend/

# Deploy ingress
kubectl apply -f ingress.yaml
```

### 5. Verify Deployment

```bash
# Check pods
kubectl get pods -n todo-app

# Check services
kubectl get svc -n todo-app

# Check ingress
kubectl get ingress -n todo-app

# Get ALB URL
kubectl get ingress todo-app-ingress -n todo-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### 6. Check Logs

```bash
# Backend logs
kubectl logs -f deployment/backend -n todo-app

# Frontend logs
kubectl logs -f deployment/frontend -n todo-app

# Describe pod for issues
kubectl describe pod <pod-name> -n todo-app
```

## Horizontal Pod Autoscaling

Both backend and frontend have HPA configured:

- **Min replicas**: 2
- **Max replicas**: 10
- **CPU target**: 70%
- **Memory target**: 80%

View HPA status:
```bash
kubectl get hpa -n todo-app
```

## Ingress Configuration

The ingress creates an Application Load Balancer with:

- **Path-based routing**:
  - `/api/*` → Backend service
  - `/*` → Frontend service
- **Health checks** on `/health` endpoints
- **Internet-facing** scheme

### Enable HTTPS

To enable HTTPS, uncomment and configure in `ingress.yaml`:

1. Request an ACM certificate
2. Update the certificate ARN
3. Uncomment HTTPS annotations

## Troubleshooting

### Pods not starting

```bash
kubectl describe pod <pod-name> -n todo-app
kubectl logs <pod-name> -n todo-app
```

### Backend can't access DynamoDB

- Verify IRSA role ARN in serviceaccount.yaml
- Check IAM policy has DynamoDB permissions
- Verify AWS credentials in pod:
  ```bash
  kubectl exec -it <backend-pod> -n todo-app -- env | grep AWS
  ```

### Ingress not creating ALB

- Check AWS Load Balancer Controller is running
- View controller logs:
  ```bash
  kubectl logs -n kube-system deployment/aws-load-balancer-controller
  ```

### HPA not scaling

- Verify metrics-server is installed:
  ```bash
  kubectl get deployment metrics-server -n kube-system
  ```
- Check HPA status:
  ```bash
  kubectl describe hpa <hpa-name> -n todo-app
  ```

## Updating the Application

### Rolling update

```bash
# Update image tag in deployment.yaml
kubectl apply -f backend/deployment.yaml
kubectl apply -f frontend/deployment.yaml

# Or use kubectl set image
kubectl set image deployment/backend backend=YOUR_REGISTRY/todo-backend:v2 -n todo-app
```

### Rollback

```bash
kubectl rollout undo deployment/backend -n todo-app
kubectl rollout undo deployment/frontend -n todo-app
```

## Cleanup

```bash
# Delete all resources
kubectl delete -f ingress.yaml
kubectl delete -f frontend/
kubectl delete -f backend/
kubectl delete -f namespace.yaml
```

## Production Considerations

1. **Secrets Management**: Use AWS Secrets Manager or External Secrets Operator
2. **Monitoring**: Install Prometheus and Grafana
3. **Logging**: Configure CloudWatch Container Insights
4. **Network Policies**: Add network policies for pod-to-pod communication
5. **Resource Quotas**: Set namespace resource quotas
6. **Pod Disruption Budgets**: Add PDBs for high availability
7. **HTTPS**: Enable SSL/TLS with ACM certificates
8. **WAF**: Add AWS WAF to the ALB for security
