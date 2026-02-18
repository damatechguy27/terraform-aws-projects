# EKS Platform - Production-Grade Terraform Infrastructure

This repository contains production-grade Terraform modules for deploying Amazon EKS (Elastic Kubernetes Service) clusters with best practices for high availability, security, and cost optimization.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│  EKS Cluster (Multi-AZ)                                     │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐      ┌──────────────┐                    │
│  │ EKS Cluster  │──┬──▶│ Node Group   │                    │
│  │ - Control    │  │   │ (System)     │                    │
│  │   Plane      │  │   └──────────────┘                    │
│  │ - OIDC       │  │                                        │
│  │   Provider   │  │   ┌──────────────┐                    │
│  │ - IAM Roles  │  └──▶│ Node Group   │                    │
│  │ - Security   │      │ (Workload)   │                    │
│  │   Groups     │      └──────────────┘                    │
│  └──────┬───────┘                                           │
│         │              ┌──────────────┐                    │
│         └─────────────▶│ IRSA Module  │                    │
│                        │ - IAM Role   │                    │
│                        │ - K8s SA     │                    │
│                        └──────┬───────┘                    │
│                               │                             │
│                               ▼                             │
│                        ┌──────────────┐                    │
│                        │ AWS LB Ctrl  │──▶ ALB/NLB        │
│                        └──────────────┘                    │
└─────────────────────────────────────────────────────────────┘
```

## Features

- **Multi-AZ High Availability**: EKS cluster and nodes deployed across multiple availability zones
- **AWS Load Balancer Controller**: Native integration with AWS ALB and NLB
- **IRSA (IAM Roles for Service Accounts)**: Secure pod-to-AWS API access without credentials
- **Remote State Management**: S3 backend with DynamoDB locking for safe collaboration
- **Cost Optimization**: Tagged resources, right-sized instances, configurable Spot instances
- **Security Best Practices**: Least-privilege IAM, encrypted secrets, private subnets support
- **DRY Principles**: Reusable modules with clear separation of concerns

## Project Structure

```
.
├── modules/                    # Reusable Terraform modules
│   ├── eks-cluster/           # EKS control plane + OIDC + IAM + SGs
│   ├── eks-node-group/        # Managed node groups
│   ├── eks-irsa/              # IAM Roles for Service Accounts
│   └── eks-ingress-controller/ # AWS Load Balancer Controller
│
├── branches/                  # Branch-specific environments
│   ├── tech-branch-est/      # us-east-2 deployments
│   │   ├── dev/              # Development environment
│   │   ├── stg/              # Staging environment (future)
│   │   └── prd/              # Production environment (future)
│   └── tech-branch-wst/      # us-west-2 deployments (future)
│
├── scripts/                   # Utility scripts
│   └── setup-backend.sh      # S3/DynamoDB backend setup
│
├── shared/                    # Shared templates and configs
│   ├── backend-template.tf.example
│   └── provider-template.tf.example
│
├── .gitignore
├── .terraform-version
└── README.md
```

## Prerequisites

Before deploying, ensure you have:

1. **AWS CLI** (version 2.x or higher)
   ```bash
   aws --version
   ```

2. **Terraform** (version 1.7.0)
   ```bash
   terraform version
   ```

3. **kubectl** (version 1.27 or higher)
   ```bash
   kubectl version --client
   ```

4. **AWS Credentials** configured
   ```bash
   aws configure
   # OR set environment variables:
   export AWS_ACCESS_KEY_ID="..."
   export AWS_SECRET_ACCESS_KEY="..."
   export AWS_DEFAULT_REGION="us-east-2"
   ```

5. **Required IAM Permissions**:
   - EKS full access
   - EC2 full access (for nodes, security groups, VPC)
   - IAM role creation and policy management
   - S3 and DynamoDB (for Terraform state)
   - CloudWatch Logs

## Quick Start

### Step 1: Set Up Backend Resources

Run the setup script to create S3 bucket and DynamoDB table for Terraform state:

```bash
# For us-east-2 (tech-branch-est)
./scripts/setup-backend.sh us-east-2

# For us-west-2 (tech-branch-wst)
./scripts/setup-backend.sh us-west-2
```

This creates:
- S3 bucket: `eks-platform-terraform-state`
- DynamoDB table: `eks-platform-terraform-locks`

### Step 2: Configure Environment

Navigate to your target environment:

```bash
cd branches/tech-branch-est/dev
```

Copy and customize the variables file:

```bash
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars
```

### Step 3: Initialize Terraform

```bash
terraform init
```

### Step 4: Review the Plan

```bash
terraform plan
```

Review the output carefully:
- ✓ Check resource names follow convention
- ✓ Verify subnets span at least 2 AZs
- ✓ Confirm tags are applied
- ✓ No unexpected resource deletions

### Step 5: Deploy Infrastructure

```bash
terraform apply
```

Expected duration: ~15-20 minutes
- EKS cluster: ~10 minutes
- Node groups: ~5 minutes
- Helm chart (AWS LB Controller): ~2 minutes

### Step 6: Configure kubectl

```bash
aws eks update-kubeconfig --name eks-platform-est-dev-eks --region us-east-2
kubectl get nodes
```

Expected output:
```
NAME                                        STATUS   ROLES    AGE   VERSION
ip-172-31-x-x.us-east-2.compute.internal    Ready    <none>   5m    v1.29.x
ip-172-31-y-y.us-east-2.compute.internal    Ready    <none>   5m    v1.29.x
```

## Modules

### 1. EKS Cluster Module

Creates EKS control plane with OIDC provider, IAM roles, and security groups.

**Location**: [`modules/eks-cluster/`](modules/eks-cluster/)

**Key Features**:
- Multi-AZ EKS control plane
- OIDC provider for IRSA
- Cluster and node IAM roles
- Security groups with least-privilege rules
- CloudWatch logging

**Usage**:
```hcl
module "eks_cluster" {
  source = "../../../modules/eks-cluster"

  project_name      = "eks-platform"
  environment       = "dev"
  branch_identifier = "est"
  cluster_version   = "1.29"
  vpc_id            = data.aws_vpc.selected.id
  subnet_ids        = data.aws_subnets.selected.ids

  tags = local.common_tags
}
```

### 2. EKS Node Group Module

Creates managed node groups with launch templates and auto-scaling.

**Location**: [`modules/eks-node-group/`](modules/eks-node-group/)

**Key Features**:
- Launch template with EBS encryption
- Auto-scaling configuration
- Support for ON_DEMAND and SPOT instances
- Kubernetes labels and taints

**Usage**:
```hcl
module "eks_node_group_system" {
  source = "../../../modules/eks-node-group"

  cluster_name           = module.eks_cluster.cluster_name
  node_group_name        = "eks-platform-est-dev-system"
  node_role_arn          = module.eks_cluster.node_iam_role_arn
  subnet_ids             = data.aws_subnets.selected.ids
  node_security_group_id = module.eks_cluster.node_security_group_id

  instance_types = ["t3.medium"]
  capacity_type  = "ON_DEMAND"
  desired_size   = 2
  min_size       = 2
  max_size       = 4

  tags = local.common_tags
}
```

### 3. IRSA Module

Creates IAM Roles for Service Accounts with OIDC trust policies.

**Location**: [`modules/eks-irsa/`](modules/eks-irsa/)

**Key Features**:
- IAM role with OIDC trust policy
- Kubernetes service account with annotations
- Support for managed and inline policies

**Usage**:
```hcl
module "irsa_aws_lb_controller" {
  source = "../../../modules/eks-irsa"

  service_account_name = "aws-load-balancer-controller"
  namespace            = "kube-system"
  cluster_name         = module.eks_cluster.cluster_name
  oidc_provider_arn    = module.eks_cluster.cluster_oidc_provider_arn
  oidc_provider_url    = replace(module.eks_cluster.cluster_oidc_issuer_url, "https://", "")

  role_name        = "eks-platform-est-dev-aws-lb-controller"
  role_policy_arns = [aws_iam_policy.aws_lb_controller.arn]

  tags = local.common_tags
}
```

### 4. Ingress Controller Module

Deploys AWS Load Balancer Controller via Helm.

**Location**: [`modules/eks-ingress-controller/`](modules/eks-ingress-controller/)

**Key Features**:
- Helm chart deployment
- AWS ALB and NLB integration
- High availability with multiple replicas

**Usage**:
```hcl
module "ingress_controller" {
  source = "../../../modules/eks-ingress-controller"

  cluster_name             = module.eks_cluster.cluster_name
  vpc_id                   = data.aws_vpc.selected.id
  service_account_role_arn = module.irsa_aws_lb_controller.iam_role_arn

  chart_version = "1.7.1"
  replica_count = 2

  depends_on = [module.eks_node_group_system]
}
```

## Post-Deployment

### Verify Cluster

```bash
# Check cluster info
kubectl cluster-info

# Check nodes
kubectl get nodes -o wide

# Check AWS Load Balancer Controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check IRSA setup
kubectl get sa aws-load-balancer-controller -n kube-system -o yaml
```

### Deploy Test Application

Deploy a sample nginx app with ALB ingress:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: test-app
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-test
  namespace: test-app
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
  name: nginx-test
  namespace: test-app
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
  name: nginx-test
  namespace: test-app
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx-test
            port:
              number: 80
EOF
```

Wait for ALB to be provisioned (~2-3 minutes):

```bash
kubectl get ingress -n test-app -w
```

Test access:

```bash
INGRESS_URL=$(kubectl get ingress nginx-test -n test-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl http://$INGRESS_URL
```

Cleanup:

```bash
kubectl delete namespace test-app
```

## Cost Estimates

### Development Environment (tech-branch-est/dev)

| Resource | Quantity | Monthly Cost |
|----------|----------|--------------|
| EKS Control Plane | 1 | $73 |
| EC2 t3.medium (on-demand) | 2 | ~$60 |
| EBS volumes (20GB each) | 2 | ~$3 |
| CloudWatch Logs (7 days) | ~5GB | ~$5 |
| **Total** | | **~$141/month** |

### Cost Optimization Tips

1. **Use Spot Instances**: Save up to 70% for non-critical workloads
2. **Right-Size Instances**: Monitor usage and adjust instance types
3. **Cluster Autoscaler**: Scale down during off-hours
4. **Log Retention**: Reduce CloudWatch log retention (currently 7 days for dev)
5. **Reserved Capacity**: Use Savings Plans for predictable baseline

## Expanding to Other Environments

### Adding Staging/Production (same region)

```bash
# Copy dev configuration
cp -r branches/tech-branch-est/dev branches/tech-branch-est/stg

# Update environment-specific values
cd branches/tech-branch-est/stg
vim locals.tf  # Change environment = "stg"
vim backend.tf  # Change state key
vim main.tf  # Adjust node counts, instance types

terraform init
terraform plan
terraform apply
```

### Adding West Region (us-west-2)

```bash
# Copy entire east branch
cp -r branches/tech-branch-est branches/tech-branch-wst

# Update branch-specific values
find branches/tech-branch-wst -type f -name "*.tf" -exec sed -i 's/est/wst/g' {} \;
find branches/tech-branch-wst -type f -name "*.tf" -exec sed -i 's/us-east-2/us-west-2/g' {} \;

# Set up backend resources in us-west-2
./scripts/setup-backend.sh us-west-2

cd branches/tech-branch-wst/dev
terraform init
terraform plan
terraform apply
```

## Maintenance

### Upgrading EKS Cluster Version

```bash
cd branches/tech-branch-est/dev

# Update cluster version in variables.tf
vim variables.tf  # Change cluster_version = "1.30"

# Plan and review changes
terraform plan

# Apply upgrade (control plane first, then nodes)
terraform apply

# Update kubeconfig
aws eks update-kubeconfig --name eks-platform-est-dev-eks --region us-east-2

# Verify upgrade
kubectl version
```

### Updating Node Groups

```bash
# Modify node group configuration
vim main.tf  # Update instance_types, desired_size, etc.

# Plan and apply
terraform plan
terraform apply

# Rolling update happens automatically (max_unavailable = 1)
```

## Troubleshooting

### Issue: Nodes not joining cluster

**Check**:
```bash
aws eks describe-cluster --name eks-platform-est-dev-eks --region us-east-2 --query cluster.status
```

**Common causes**:
- IAM role permissions missing
- Security group rules blocking communication
- Subnets not properly tagged

### Issue: AWS Load Balancer Controller not working

**Check**:
```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

**Common causes**:
- IRSA role missing required IAM permissions
- VPC ID mismatch
- Subnets missing required tags

### Issue: State lock error

```bash
# Manually release lock (use with caution)
aws dynamodb delete-item \
  --table-name eks-platform-terraform-locks \
  --key '{"LockID":{"S":"eks-platform-terraform-state/eks/tech-branch-est/dev/terraform.tfstate"}}'
```

## Security Considerations

1. **Secrets Management**: Never commit `.tfvars` files with secrets
2. **IAM Least Privilege**: All roles follow least-privilege principle
3. **Network Security**: Use private subnets for production
4. **Encryption**: EBS volumes encrypted, consider KMS for Kubernetes secrets
5. **Audit Logging**: EKS control plane logs enabled in CloudWatch

## Contributing

When contributing to this project:

1. Follow the established module structure
2. Use `terraform fmt` before committing
3. Run `terraform validate` to check syntax
4. Test changes in dev environment first
5. Update README if adding new features

## License

This project is licensed under the MIT License.

## Support

For issues and questions:
- Open an issue in the repository
- Review module READMEs for detailed documentation
- Check AWS EKS documentation: https://docs.aws.amazon.com/eks/

## References

- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [EKS Workshop](https://www.eksworkshop.com/)
