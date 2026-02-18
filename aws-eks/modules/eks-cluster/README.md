# EKS Cluster Module

This module creates an Amazon EKS cluster with all required supporting resources including OIDC provider, IAM roles, security groups, and CloudWatch logging.

## Features

- Multi-AZ EKS control plane
- OIDC provider for IRSA (IAM Roles for Service Accounts)
- Cluster and node IAM roles with managed policies
- Security groups with least-privilege rules
- CloudWatch log group with configurable retention
- Optional KMS encryption for Kubernetes secrets

## Usage

```hcl
module "eks_cluster" {
  source = "../../modules/eks-cluster"

  # Project identification
  project_name      = "eks-platform"
  environment       = "dev"
  branch_identifier = "est"

  # Cluster configuration
  cluster_version = "1.29"

  # Network configuration
  vpc_id     = data.aws_vpc.selected.id
  subnet_ids = data.aws_subnets.selected.ids  # Must span 2+ AZs

  # Endpoint access
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # Logging
  enabled_cluster_log_types  = ["api", "audit", "authenticator"]
  cluster_log_retention_days = 7

  # Tags
  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_name | Project name for resource naming | string | - | yes |
| environment | Environment (dev, stg, prd) | string | - | yes |
| branch_identifier | Branch identifier (est, wst) | string | - | yes |
| cluster_version | Kubernetes version | string | "1.29" | no |
| vpc_id | VPC ID for cluster | string | - | yes |
| subnet_ids | Subnet IDs (must span 2+ AZs) | list(string) | - | yes |
| cluster_endpoint_public_access | Enable public endpoint | bool | true | no |
| cluster_endpoint_private_access | Enable private endpoint | bool | true | no |
| enabled_cluster_log_types | Control plane log types | list(string) | ["api", "audit", ...] | no |
| cluster_log_retention_days | CloudWatch log retention | number | 7 | no |
| tags | Additional tags | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_id | EKS cluster ID |
| cluster_name | EKS cluster name |
| cluster_endpoint | Cluster API endpoint URL |
| cluster_ca_cert | Cluster CA certificate (base64) |
| cluster_oidc_provider_arn | OIDC provider ARN for IRSA |
| cluster_oidc_provider_url | OIDC provider URL (without https://) |
| node_iam_role_arn | IAM role ARN for nodes |
| node_security_group_id | Security group ID for nodes |

## Resources Created

- `aws_eks_cluster` - EKS control plane
- `aws_iam_openid_connect_provider` - OIDC provider for IRSA
- `aws_iam_role` (cluster) - Cluster IAM role
- `aws_iam_role` (node) - Node IAM role
- `aws_iam_instance_profile` - Instance profile for nodes
- `aws_security_group` (cluster) - Cluster security group
- `aws_security_group` (node) - Node security group
- `aws_cloudwatch_log_group` - Control plane logs
- Multiple security group rules for cluster-node communication

## Security Group Rules

### Cluster Security Group

**Egress**:
- Allow to node SG on port 443 (HTTPS)
- Allow to node SG on port 10250 (kubelet API)
- Allow to node SG on ports 1025-65535 (ephemeral)

### Node Security Group

**Ingress**:
- Allow from self on all ports (node-to-node)
- Allow from cluster SG on port 443
- Allow from cluster SG on port 10250
- Allow from cluster SG on ports 1025-65535

**Egress**:
- Allow to cluster SG on port 443
- Allow to internet on all ports (for pulling images, etc.)

## IAM Roles

### Cluster Role

**Managed Policies**:
- `AmazonEKSClusterPolicy`
- `AmazonEKSVPCResourceController`

### Node Role

**Managed Policies**:
- `AmazonEKSWorkerNodePolicy`
- `AmazonEKS_CNI_Policy`
- `AmazonEC2ContainerRegistryReadOnly`
- `AmazonSSMManagedInstanceCore` (for Session Manager access)

## High Availability

This module follows AWS best practices for HA:

1. **Multi-AZ Control Plane**: EKS control plane is automatically distributed across 3 AZs by AWS
2. **Multi-AZ Nodes**: Subnet IDs must span at least 2 AZs (validated via input validation)
3. **Private and Public Access**: Both enabled by default for flexibility and HA

## Example: Custom Encryption

```hcl
module "eks_cluster" {
  source = "../../modules/eks-cluster"

  # ... other configuration ...

  # Enable KMS encryption for Kubernetes secrets
  cluster_encryption_config_enable     = true
  cluster_encryption_config_kms_key_id = aws_kms_key.eks.arn
}

resource "aws_kms_key" "eks" {
  description             = "EKS cluster encryption key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}
```

## Notes

- Cluster creation takes approximately 10-15 minutes
- OIDC provider thumbprint is automatically retrieved via TLS certificate data source
- Security groups allow cluster-node communication bidirectionally
- CloudWatch log group is created before cluster to ensure logs are captured from startup
- Node IAM role can be used by multiple node groups
