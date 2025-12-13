# Karpenter Auto-Scaling

Karpenter is a flexible, high-performance Kubernetes cluster autoscaler that provisions right-sized compute resources in response to changing application load.

## Why Karpenter?

### Advantages over Cluster Autoscaler

1. **Faster Scaling**: Provisions nodes in seconds, not minutes
2. **Cost Optimization**: Automatically selects the most cost-effective instance types
3. **Bin Packing**: Efficiently packs pods onto nodes
4. **Spot Instance Support**: Seamlessly handles spot interruptions
5. **Flexible Configuration**: Fine-grained control over node provisioning
6. **No Node Groups**: Provisions individual instances, not node groups

### Key Features

- **Just-in-Time Provisioning**: Launches nodes only when needed
- **Consolidation**: Removes underutilized nodes automatically
- **Diverse Instance Types**: Can provision any instance type that meets requirements
- **Spot and On-Demand**: Mix of instance purchasing options
- **Interruption Handling**: Gracefully handles spot interruptions

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Kubernetes Cluster                       │
│                                                              │
│  ┌────────────────┐         ┌──────────────────┐           │
│  │  Pending Pods  │────────▶│    Karpenter     │           │
│  └────────────────┘         │   Controller     │           │
│                             └────────┬─────────┘           │
│                                      │                      │
│                                      ▼                      │
│                             ┌────────────────┐             │
│                             │   NodePool     │             │
│                             │ EC2NodeClass   │             │
│                             └────────┬───────┘             │
└──────────────────────────────────────┼──────────────────────┘
                                       │
                                       ▼
                        ┌──────────────────────────┐
                        │      AWS EC2 API         │
                        │  (Launch Instances)      │
                        └──────────────────────────┘
```

## Components

### 1. Karpenter Controller
- Watches for unschedulable pods
- Provisions nodes based on NodePool configuration
- Handles node consolidation and deprovisioning

### 2. NodePool
- Defines requirements for nodes (instance types, capacity type, etc.)
- Sets limits and disruption budgets
- Configures consolidation behavior

### 3. EC2NodeClass
- AWS-specific configuration
- AMI selection
- Subnet and security group selection
- IAM instance profile
- User data and tags

## Installation

### Prerequisites

- EKS cluster deployed via Terraform
- kubectl configured
- Helm installed
- AWS credentials configured

### Quick Install

```bash
cd k8s/karpenter
./install-karpenter.sh
```

Or with custom parameters:
```bash
./install-karpenter.sh todo-app-cluster us-east-1 v0.33.0
```

### Manual Installation

1. **Create namespace**:
```bash
kubectl apply -f namespace.yaml
```

2. **Update service account** with Karpenter controller role ARN from Terraform:
```bash
# Get role ARN
cd terraform
terraform output karpenter_controller_role_arn

# Update serviceaccount.yaml with the ARN
kubectl apply -f k8s/karpenter/serviceaccount.yaml
```

3. **Install Karpenter via Helm**:
```bash
export CLUSTER_NAME=todo-app-cluster
export AWS_REGION=us-east-1
export KARPENTER_VERSION=v0.33.0

helm repo add karpenter https://charts.karpenter.sh/
helm repo update

helm upgrade --install karpenter karpenter/karpenter \
  --namespace karpenter \
  --version ${KARPENTER_VERSION} \
  --set serviceAccount.create=false \
  --set serviceAccount.name=karpenter \
  --set settings.clusterName=${CLUSTER_NAME} \
  --set settings.clusterEndpoint=$(aws eks describe-cluster --name ${CLUSTER_NAME} --region ${AWS_REGION} --query "cluster.endpoint" --output text) \
  --set settings.interruptionQueue=$(terraform output -raw karpenter_queue_name) \
  --wait
```

4. **Deploy NodePool and EC2NodeClass**:
```bash
kubectl apply -f nodepool.yaml
```

## Configuration

### NodePool Configuration

The default NodePool is configured for general workloads:

**Instance Selection**:
- Capacity types: On-Demand and Spot (50/50 mix for cost optimization)
- Instance categories: t, c, m, r (general purpose, compute, memory)
- Instance generations: 3+ (modern instances)
- Instance sizes: small, medium, large

**Limits**:
- Max CPU: 100 cores
- Max Memory: 200Gi

**Disruption**:
- Consolidation: Enabled (removes underutilized nodes)
- Consolidation delay: 30 seconds
- Disruption budget: 10% of nodes

### EC2NodeClass Configuration

**AMI**: Amazon Linux 2 (AL2)
**Subnets**: Private subnets tagged with `karpenter.sh/discovery`
**Security Groups**: EKS node security group
**Instance Profile**: Karpenter node role
**Storage**: 50GB gp3 EBS volume

### Customization

#### Prefer On-Demand Instances

```yaml
requirements:
  - key: karpenter.sh/capacity-type
    operator: In
    values: ["on-demand"]
```

#### Prefer Specific Instance Types

```yaml
requirements:
  - key: node.kubernetes.io/instance-type
    operator: In
    values: ["t3.medium", "t3.large"]
```

#### Add Node Taints

```yaml
taints:
  - key: workload-type
    value: compute-intensive
    effect: NoSchedule
```

#### Adjust Consolidation

```yaml
disruption:
  consolidationPolicy: WhenEmpty  # Only consolidate empty nodes
  consolidateAfter: 5m            # Wait 5 minutes before consolidating
```

## Usage

### Automatic Scaling

Karpenter automatically provisions nodes when pods are pending:

1. Pod is created but cannot be scheduled
2. Karpenter detects the pending pod
3. Karpenter calculates required node size
4. Karpenter provisions the most cost-effective node
5. Pod is scheduled on the new node

### Monitoring

**View Karpenter logs**:
```bash
kubectl logs -f -n karpenter -l app.kubernetes.io/name=karpenter
```

**View NodePools**:
```bash
kubectl get nodepool
kubectl describe nodepool default
```

**View EC2NodeClasses**:
```bash
kubectl get ec2nodeclass
kubectl describe ec2nodeclass default
```

**View Karpenter-managed nodes**:
```bash
kubectl get nodes -l karpenter.sh/nodepool=default
```

**View node capacity**:
```bash
kubectl get nodes -o custom-columns=NAME:.metadata.name,INSTANCE:.metadata.labels.node\\.kubernetes\\.io/instance-type,CAPACITY:.metadata.labels.karpenter\\.sh/capacity-type
```

### Testing Auto-Scaling

Create a deployment that requires scaling:

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inflate
  namespace: default
spec:
  replicas: 0
  selector:
    matchLabels:
      app: inflate
  template:
    metadata:
      labels:
        app: inflate
    spec:
      containers:
      - name: inflate
        image: public.ecr.aws/eks-distro/kubernetes/pause:3.7
        resources:
          requests:
            cpu: 1
            memory: 1.5Gi
EOF

# Scale up to trigger node provisioning
kubectl scale deployment inflate --replicas=10

# Watch Karpenter provision nodes
kubectl logs -f -n karpenter -l app.kubernetes.io/name=karpenter

# Watch nodes being added
kubectl get nodes -w

# Scale down to trigger consolidation
kubectl scale deployment inflate --replicas=0

# Watch Karpenter remove nodes
kubectl logs -f -n karpenter -l app.kubernetes.io/name=karpenter
```

## Interruption Handling

Karpenter handles spot instance interruptions gracefully:

1. **EventBridge** sends interruption warning to SQS queue
2. **Karpenter** receives the event
3. **Karpenter** cordons the node
4. **Karpenter** drains pods to other nodes
5. **Karpenter** provisions replacement node if needed

### Interruption Events Handled

- Spot Instance Interruption Warning (2-minute notice)
- Instance State Change Notifications
- EC2 Rebalance Recommendations
- AWS Health Events

## Cost Optimization

### Spot Instance Strategy

Karpenter uses spot instances by default (50/50 mix):

**Benefits**:
- Up to 90% cost savings vs On-Demand
- Automatic fallback to On-Demand if spot unavailable
- Diversification across instance types reduces interruption risk

**Best Practices**:
- Use for stateless workloads
- Implement pod disruption budgets
- Use multiple instance types
- Handle interruptions gracefully

### Consolidation

Karpenter automatically consolidates nodes:

**When**:
- Node is underutilized
- Pods can fit on fewer nodes
- After consolidation delay (30s default)

**How**:
- Identifies underutilized nodes
- Simulates pod placement on fewer nodes
- Cordons and drains nodes
- Terminates empty nodes

### Right-Sizing

Karpenter selects the most cost-effective instance:

- Considers pod resource requests
- Evaluates multiple instance types
- Chooses smallest instance that fits
- Prefers spot when available

## Troubleshooting

### Pods Not Scheduling

**Check Karpenter logs**:
```bash
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter | grep -i error
```

**Check NodePool status**:
```bash
kubectl describe nodepool default
```

**Common issues**:
- Insufficient capacity in region
- NodePool limits reached
- Pod requirements too specific
- Security group or subnet issues

### Nodes Not Provisioning

**Verify IAM permissions**:
```bash
# Check Karpenter controller role
aws iam get-role --role-name todo-app-cluster-karpenter-controller

# Check node role
aws iam get-role --role-name todo-app-cluster-karpenter-node
```

**Verify tags**:
```bash
# Check subnet tags
aws ec2 describe-subnets --filters "Name=tag:karpenter.sh/discovery,Values=todo-app-cluster"

# Check security group tags
aws ec2 describe-security-groups --filters "Name=tag:karpenter.sh/discovery,Values=todo-app-cluster"
```

### Nodes Not Consolidating

**Check consolidation settings**:
```bash
kubectl get nodepool default -o yaml | grep -A 5 disruption
```

**Force consolidation**:
```bash
# Add annotation to trigger consolidation
kubectl annotate node <node-name> karpenter.sh/do-not-consolidate-
```

### Spot Interruptions

**View interruption events**:
```bash
kubectl get events -n karpenter --sort-by='.lastTimestamp'
```

**Check SQS queue**:
```bash
aws sqs get-queue-attributes \
  --queue-url $(aws sqs get-queue-url --queue-name todo-app-cluster-karpenter --query QueueUrl --output text) \
  --attribute-names All
```

## Best Practices

### 1. Set Resource Requests

Always set resource requests on pods:
```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
```

### 2. Use Pod Disruption Budgets

Protect critical workloads:
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: backend-pdb
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: backend
```

### 3. Diversify Instance Types

Allow multiple instance types for better availability:
```yaml
requirements:
  - key: karpenter.k8s.aws/instance-category
    operator: In
    values: ["t", "c", "m"]
```

### 4. Monitor Costs

Use AWS Cost Explorer to track Karpenter costs:
- Filter by tag: `ManagedBy=karpenter`
- Compare spot vs on-demand usage
- Identify optimization opportunities

### 5. Test Interruptions

Regularly test spot interruption handling:
```bash
# Simulate interruption
aws ec2 terminate-instances --instance-ids <instance-id>
```

## Migration from Cluster Autoscaler

If migrating from Cluster Autoscaler:

1. **Deploy Karpenter** alongside Cluster Autoscaler
2. **Create NodePool** with similar configuration
3. **Scale down** Cluster Autoscaler managed node groups
4. **Monitor** Karpenter provisioning
5. **Remove** Cluster Autoscaler when confident

## Uninstall

```bash
# Delete NodePool and EC2NodeClass
kubectl delete nodepool default
kubectl delete ec2nodeclass default

# Uninstall Karpenter
helm uninstall karpenter -n karpenter

# Delete namespace
kubectl delete namespace karpenter
```

## Resources

- [Karpenter Documentation](https://karpenter.sh/)
- [Karpenter GitHub](https://github.com/aws/karpenter)
- [AWS Karpenter Best Practices](https://aws.github.io/aws-eks-best-practices/karpenter/)
- [Karpenter Slack](https://kubernetes.slack.com/archives/C02SFFZSA2K)

## Support

For issues:
1. Check Karpenter logs
2. Review AWS CloudWatch logs
3. Check GitHub issues
4. Ask in Kubernetes Slack #karpenter

---

**Karpenter is now managing your cluster auto-scaling!**
