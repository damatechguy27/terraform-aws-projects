# Simple EKS - Production-Ready Terraform Configuration

A production-grade AWS EKS deployment with managed node group and AWS Load Balancer Controller ingress, following security and high-availability best practices.

## Features

- **EKS Cluster** - Kubernetes 1.29 with multi-AZ control plane
- **Managed Node Group** - 2 nodes (default) with auto-scaling capabilities
- **AWS Load Balancer Controller** - Automatic ALB/NLB provisioning for Ingress resources
- **IRSA (IAM Roles for Service Accounts)** - Least-privilege security model
- **Multi-AZ Deployment** - High availability across availability zones
- **CloudWatch Logging** - Control plane logs with configurable retention
- **Cost-Optimized** - Right-sized resources with tagging for cost allocation

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         AWS Region                          │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                       VPC                            │  │
│  │                                                      │  │
│  │  ┌─────────────────┐       ┌─────────────────┐     │  │
│  │  │   AZ-1          │       │   AZ-2          │     │  │
│  │  │                 │       │                 │     │  │
│  │  │  ┌───────────┐  │       │  ┌───────────┐  │     │  │
│  │  │  │ EKS Node  │  │       │  │ EKS Node  │  │     │  │
│  │  │  │ t3.medium │  │       │  │ t3.medium │  │     │  │
│  │  │  └───────────┘  │       │  └───────────┘  │     │  │
│  │  │                 │       │                 │     │  │
│  │  └─────────────────┘       └─────────────────┘     │  │
│  │                                                      │  │
│  │  ┌────────────────────────────────────────────┐     │  │
│  │  │      EKS Control Plane (Multi-AZ)          │     │  │
│  │  │  - API Server                              │     │  │
│  │  │  - etcd                                    │     │  │
│  │  │  - Controller Manager                      │     │  │
│  │  │  - Scheduler                               │     │  │
│  │  └────────────────────────────────────────────┘     │  │
│  │                                                      │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         AWS Load Balancer Controller (IRSA)          │  │
│  │  - Watches for Ingress resources                     │  │
│  │  - Creates ALB/NLB automatically                     │  │
│  │  - Manages target groups                             │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

### Required Tools

- **Terraform** >= 1.7.0 - [Install](https://developer.hashicorp.com/terraform/downloads)
- **AWS CLI** >= 2.0 - [Install](https://aws.amazon.com/cli/)
- **kubectl** - [Install](https://kubernetes.io/docs/tasks/tools/)
- **helm** - [Install](https://helm.sh/docs/intro/install/)

### AWS Permissions

Your AWS credentials must have permissions to create:
- EKS clusters and node groups
- IAM roles and policies
- VPC security groups
- CloudWatch log groups
- OIDC identity providers

## Quick Start

### 1. Clone and Navigate

```bash
cd /workspaces/dev-container-terraform/terraform-aws-projects/simple-eks
```

### 2. Configure Variables

```bash
# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your preferences (optional - defaults work fine)
vim terraform.tfvars
```

Default configuration:
- Region: `us-east-2`
- Cluster version: `1.29`
- Node count: 2 (min: 2, max: 4)
- Instance type: `t3.medium`
- Capacity: `ON_DEMAND`

### 3. Initialize Terraform

```bash
terraform init
```

This downloads required providers:
- AWS provider ~> 5.0
- Kubernetes provider ~> 2.25
- Helm provider ~> 2.12

### 4. Review the Plan

```bash
terraform plan
```

Expected resources to be created: ~25 resources

Key resources:
- 1x EKS cluster
- 1x EKS managed node group (2 nodes)
- 2x Security groups (cluster + nodes)
- 4x IAM roles (cluster, nodes, OIDC, load balancer controller)
- 1x OIDC provider
- 1x CloudWatch log group
- 1x Kubernetes service account
- 1x Helm release (AWS Load Balancer Controller)

### 5. Deploy

```bash
terraform apply
```

Deployment takes approximately 15-20 minutes:
- EKS cluster creation: ~10 minutes
- Node group spin-up: ~5 minutes
- Ingress controller deployment: ~2 minutes

### 6. Configure kubectl

```bash
# Get the command from Terraform output
terraform output -raw configure_kubectl

# Or run directly
aws eks update-kubeconfig --region us-east-2 --name simple-eks-dev
```

### 7. Verify Deployment

```bash
# Check cluster connection
kubectl cluster-info

# Verify nodes are ready
kubectl get nodes

# Expected output:
# NAME                                       STATUS   ROLES    AGE   VERSION
# ip-xxx-xxx-xxx-xxx.us-east-2.compute...   Ready    <none>   5m    v1.29.x
# ip-xxx-xxx-xxx-xxx.us-east-2.compute...   Ready    <none>   5m    v1.29.x

# Check ingress controller pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Expected output:
# NAME                                            READY   STATUS    RESTARTS   AGE
# aws-load-balancer-controller-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
# aws-load-balancer-controller-xxxxxxxxxx-xxxxx   1/1     Running   0          2m

# View all Terraform outputs
terraform output
```

## Testing the Ingress Controller

Deploy a sample nginx application with an Application Load Balancer:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: demo
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx
  namespace: demo
spec:
  type: ClusterIP
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx
  namespace: demo
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/healthcheck-path: /
spec:
  ingressClassName: alb
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx
            port:
              number: 80
EOF
```

Wait for the ALB to provision (2-3 minutes):

```bash
# Watch for ALB creation
kubectl get ingress -n demo -w

# Get the ALB DNS name once ADDRESS column is populated
ALB_DNS=$(kubectl get ingress -n demo -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')

# Test the endpoint
curl http://$ALB_DNS

# Clean up demo
kubectl delete namespace demo
```

## Configuration

### Key Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `project_name` | `simple-eks` | Project identifier for naming |
| `environment` | `dev` | Environment (dev, staging, prod) |
| `aws_region` | `us-east-2` | AWS region for deployment |
| `cluster_version` | `1.29` | Kubernetes version |
| `node_instance_types` | `["t3.medium"]` | EC2 instance types for nodes |
| `node_desired_size` | `2` | Initial number of nodes |
| `node_min_size` | `2` | Minimum nodes (for HA) |
| `node_max_size` | `4` | Maximum nodes (for auto-scaling) |
| `node_capacity_type` | `ON_DEMAND` | ON_DEMAND or SPOT |
| `ingress_replica_count` | `2` | Ingress controller replicas |

See [terraform.tfvars.example](terraform.tfvars.example) for all options.

### Network Configuration

By default, this configuration uses the default VPC and all its subnets for multi-AZ deployment.

**For production**, create a dedicated VPC with:
- Private subnets for nodes
- Public subnets for load balancers
- NAT gateways for outbound traffic
- VPC endpoints for AWS services

Modify [data.tf](data.tf:6-16) to reference your custom VPC.

## Cost Optimization

### Estimated Monthly Costs (us-east-2)

| Component | Cost |
|-----------|------|
| EKS Control Plane | $73 |
| 2x t3.medium nodes (ON_DEMAND) | ~$60 |
| Data transfer & storage | ~$20 |
| **Total** | **~$150-200/month** |

### Development/Testing Cost Savings

1. **Use Spot Instances** - Save ~70% on compute
   ```hcl
   node_capacity_type = "SPOT"
   ```

2. **Reduce Node Count** - Save 50% on compute
   ```hcl
   node_desired_size = 1
   node_min_size     = 1
   ```

3. **Use Smaller Instances** - Save 50% per node
   ```hcl
   node_instance_types = ["t3.small"]
   ```

4. **Reduce Log Retention** - Minimal CloudWatch costs
   ```hcl
   cluster_log_retention_days = 1
   ```

5. **Schedule Downtime** - Scale to zero after hours
   ```bash
   # Scale down (manual)
   aws eks update-nodegroup-config \
     --cluster-name simple-eks-dev \
     --nodegroup-name simple-eks-dev-nodes \
     --scaling-config desiredSize=0,minSize=0,maxSize=4

   # Scale up
   aws eks update-nodegroup-config \
     --cluster-name simple-eks-dev \
     --nodegroup-name simple-eks-dev-nodes \
     --scaling-config desiredSize=2,minSize=2,maxSize=4
   ```

With all savings applied (Spot + 1 small node), dev costs: ~$80/month

### Production Cost Optimization

1. **Savings Plans or Reserved Instances** - 30-70% savings for predictable workloads
2. **Cluster Autoscaler** - Right-size based on demand
3. **Fargate for Bursty Workloads** - Pay per pod instead of over-provisioning
4. **Right-size Pods** - Set resource requests/limits based on actual usage

## Security Best Practices

### Implemented

- IAM Roles for Service Accounts (IRSA) - no static credentials
- Least-privilege IAM policies - minimal permissions for each role
- Multi-AZ node distribution - high availability
- CloudWatch logging enabled - audit trail
- Security groups - network isolation
- EKS-optimized AMI - security patches from AWS

### Additional Recommendations

1. **Private API Endpoint** (Production)
   ```hcl
   cluster_endpoint_public_access  = false
   cluster_endpoint_private_access = true
   ```

2. **Network Policies** - Pod-to-pod traffic control
   ```bash
   # Install Calico or Cilium for network policies
   kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
   ```

3. **Pod Security Standards**
   ```bash
   # Enable Pod Security Standards
   kubectl label namespace default pod-security.kubernetes.io/enforce=restricted
   ```

4. **Secrets Encryption** - Encrypt secrets at rest with KMS
   ```hcl
   # Add to aws_eks_cluster resource
   encryption_config {
     provider {
       key_arn = aws_kms_key.eks.arn
     }
     resources = ["secrets"]
   }
   ```

5. **Image Scanning** - Scan container images for vulnerabilities
   ```bash
   # Enable ECR image scanning
   # Or use tools like Trivy, Snyk, or Aqua
   ```

## High Availability

### Current Setup

- **Control Plane**: AWS-managed, Multi-AZ (3 AZs)
- **Nodes**: Distributed across all available AZs in VPC
- **Ingress Controller**: 2 replicas across different nodes
- **Auto-scaling**: Configured (min: 2, max: 4)

### Failure Scenarios

| Failure | Impact | Recovery |
|---------|--------|----------|
| Single node failure | 50% capacity loss | Auto-scaling group replaces node (~5 min) |
| AZ failure | Partial capacity loss | Remaining AZs handle traffic |
| Control plane issue | No impact on running workloads | AWS auto-repairs |
| Pod crash | Automatic restart | Kubernetes controller (~10s) |

### Improvements for Production

1. **Cluster Autoscaler** - Automatically scale nodes based on pod demand
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml
   ```

2. **Pod Disruption Budgets** - Ensure minimum replicas during updates
   ```yaml
   apiVersion: policy/v1
   kind: PodDisruptionBudget
   metadata:
     name: app-pdb
   spec:
     minAvailable: 1
     selector:
       matchLabels:
         app: your-app
   ```

3. **Multi-Region Setup** - For disaster recovery
   - Deploy identical stack in secondary region
   - Use Route53 failover routing
   - Replicate data across regions

## Operational Tasks

### Update Kubernetes Version

```bash
# Update variable
sed -i 's/cluster_version = "1.29"/cluster_version = "1.30"/' terraform.tfvars

# Apply changes (cluster updates take ~15 minutes)
terraform apply

# Update nodes (automatic with managed node groups)
# AWS will roll update with respect to max_unavailable setting
```

### Scale Node Group

```bash
# Update variables in terraform.tfvars
node_desired_size = 4
node_min_size     = 2
node_max_size     = 6

# Apply changes
terraform apply
```

### View Logs

```bash
# Control plane logs (in CloudWatch)
aws logs tail /aws/eks/simple-eks-dev/cluster --follow

# Node logs
kubectl logs -n kube-system -l k8s-app=aws-node --tail=100

# Ingress controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller -f
```

### Upgrade Ingress Controller

```bash
# Update version in terraform.tfvars
ingress_controller_version = "1.8.0"

# Apply changes
terraform apply
```

## Troubleshooting

### Nodes Not Joining Cluster

```bash
# Check node group status
aws eks describe-nodegroup \
  --cluster-name simple-eks-dev \
  --nodegroup-name simple-eks-dev-nodes

# Check EC2 instances
aws ec2 describe-instances \
  --filters "Name=tag:eks:cluster-name,Values=simple-eks-dev" \
  --query 'Reservations[].Instances[].[InstanceId,State.Name,PrivateIpAddress]'

# Check kubelet logs on node (via SSM or SSH)
journalctl -u kubelet -f
```

### Ingress Controller Not Creating ALB

```bash
# Check controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=100

# Common issues:
# 1. Insufficient IAM permissions - check IAM role
aws iam get-role --role-name simple-eks-dev-lb-controller-role

# 2. Service account not annotated correctly
kubectl describe sa aws-load-balancer-controller -n kube-system

# 3. Ingress missing required annotations
kubectl describe ingress <ingress-name> -n <namespace>
```

### Pods Stuck in Pending

```bash
# Check pod events
kubectl describe pod <pod-name> -n <namespace>

# Common causes:
# 1. Insufficient resources - scale up nodes
# 2. Node selector mismatch - check labels
# 3. Pod affinity rules - check affinity config

# Check node resource usage
kubectl top nodes
kubectl describe nodes
```

### Access Denied Errors

```bash
# Verify AWS credentials
aws sts get-caller-identity

# Update kubeconfig
aws eks update-kubeconfig --region us-east-2 --name simple-eks-dev

# Check aws-auth ConfigMap (for additional IAM users/roles)
kubectl describe configmap aws-auth -n kube-system
```

## Cleanup

### Destroy Infrastructure

```bash
# IMPORTANT: Delete all Kubernetes LoadBalancer services and Ingress resources first
# Otherwise, Terraform cannot delete VPC resources (ENIs still attached)

# Delete all ingress resources
kubectl delete ingress --all --all-namespaces

# Delete all LoadBalancer services
kubectl get svc --all-namespaces -o json | \
  jq -r '.items[] | select(.spec.type=="LoadBalancer") | "\(.metadata.namespace) \(.metadata.name)"' | \
  xargs -n 2 sh -c 'kubectl delete svc -n $0 $1'

# Wait 2-3 minutes for AWS to clean up load balancers and ENIs

# Destroy Terraform resources
terraform destroy
```

Destruction takes ~15 minutes.

### Partial Cleanup (Keep Cluster, Remove Demo Apps)

```bash
# Just remove demo applications
kubectl delete namespace demo
```

## Migrating to S3 Backend

For team collaboration and state locking, migrate to S3 backend:

```bash
# 1. Create S3 bucket and DynamoDB table (see backend.tf for commands)

# 2. Edit backend.tf - uncomment S3 backend block and add your bucket name

# 3. Migrate state
terraform init -migrate-state

# 4. Verify state is in S3
aws s3 ls s3://YOUR-BUCKET-NAME/simple-eks/dev/
```

## Next Steps

### Monitoring and Observability

1. **CloudWatch Container Insights**
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluentd-quickstart.yaml
   ```

2. **Prometheus and Grafana**
   ```bash
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm install prometheus prometheus-community/kube-prometheus-stack
   ```

### CI/CD Integration

1. **GitOps with ArgoCD**
   ```bash
   kubectl create namespace argocd
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   ```

2. **FluxCD**
   ```bash
   flux bootstrap github \
     --owner=your-org \
     --repository=your-repo \
     --path=clusters/simple-eks-dev
   ```

### Security Enhancements

1. **Falco for Runtime Security**
2. **OPA/Gatekeeper for Policy Enforcement**
3. **Vault for Secrets Management**
4. **cert-manager for TLS Certificate Management**

### Backup and Disaster Recovery

1. **Velero for Cluster Backups**
   ```bash
   helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
   helm install velero vmware-tanzu/velero --namespace velero --create-namespace
   ```

## Resources

- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [Kubernetes Documentation](https://kubernetes.io/docs/home/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## Support

For issues with this Terraform configuration, check:
1. Terraform validate: `terraform validate`
2. Terraform plan: `terraform plan`
3. AWS documentation for specific resource errors
4. Kubernetes events: `kubectl get events --all-namespaces`

## License

This is a reference architecture for educational and production use.
