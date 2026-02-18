# EKS Node Group Module

This module creates AWS EKS managed node groups with launch templates, auto-scaling configuration, and support for custom labels and taints.

## Features

- Launch template with EBS encryption and IMDSv2
- Auto-scaling configuration with update policies
- Support for ON_DEMAND and SPOT capacity types
- Kubernetes labels and taints
- Multiple instance types per node group
- CloudWatch monitoring (optional)

## Usage

```hcl
module "eks_node_group_system" {
  source = "../../modules/eks-node-group"

  # Cluster dependencies
  cluster_name           = module.eks_cluster.cluster_name
  node_role_arn          = module.eks_cluster.node_iam_role_arn
  subnet_ids             = data.aws_subnets.selected.ids
  node_security_group_id = module.eks_cluster.node_security_group_id

  # Node group configuration
  node_group_name = "eks-platform-est-dev-system"

  # Instance configuration
  instance_types = ["t3.medium"]
  ami_type       = "AL2_x86_64"
  disk_size      = 20
  disk_type      = "gp3"

  # Capacity configuration
  capacity_type = "ON_DEMAND"
  desired_size  = 2
  min_size      = 2
  max_size      = 4

  # Kubernetes configuration
  labels = {
    role = "system"
  }

  tags = {
    Environment = "dev"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| cluster_name | EKS cluster name | string | - | yes |
| node_group_name | Node group name | string | - | yes |
| node_role_arn | IAM role ARN for nodes | string | - | yes |
| subnet_ids | Subnet IDs (2+ for HA) | list(string) | - | yes |
| node_security_group_id | Security group ID | string | - | yes |
| instance_types | Instance types | list(string) | ["t3.medium"] | no |
| capacity_type | ON_DEMAND or SPOT | string | "ON_DEMAND" | no |
| ami_type | AMI type | string | "AL2_x86_64" | no |
| disk_size | Disk size in GB | number | 20 | no |
| disk_type | Disk type (gp3, gp2, io1, io2) | string | "gp3" | no |
| desired_size | Desired node count | number | 2 | no |
| min_size | Minimum node count | number | 2 | no |
| max_size | Maximum node count | number | 4 | no |
| labels | Kubernetes labels | map(string) | {} | no |
| taints | Kubernetes taints | list(object) | [] | no |
| tags | Additional tags | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| node_group_id | Node group ID |
| node_group_arn | Node group ARN |
| node_group_status | Node group status |
| autoscaling_group_name | Auto Scaling Group name |
| launch_template_id | Launch template ID |

## Resources Created

- `aws_launch_template` - Launch template for nodes
- `aws_eks_node_group` - Managed node group

## Launch Template Configuration

The launch template includes:

- **Block Device Mapping**: Root volume with specified size and type
- **EBS Encryption**: Enabled by default
- **Monitoring**: Optional detailed CloudWatch monitoring
- **Network Interfaces**: Private IP addresses, security group attachment
- **Metadata Options**: IMDSv2 enforced (security best practice)
- **Tags**: Applied to instances, volumes, and network interfaces

## Auto-Scaling Configuration

The node group supports rolling updates with:

- `max_unavailable = 1` - Only one node unavailable during updates
- Automatic scaling based on demand (when using Cluster Autoscaler)
- Lifecycle management prevents disruption during updates

## Example: Spot Instance Node Group

```hcl
module "eks_node_group_workload" {
  source = "../../modules/eks-node-group"

  cluster_name           = module.eks_cluster.cluster_name
  node_group_name        = "workload-spot"
  node_role_arn          = module.eks_cluster.node_iam_role_arn
  subnet_ids             = data.aws_subnets.selected.ids
  node_security_group_id = module.eks_cluster.node_security_group_id

  # Multiple instance types for better Spot availability
  instance_types = ["t3.medium", "t3a.medium", "t2.medium"]
  capacity_type  = "SPOT"

  desired_size = 3
  min_size     = 1
  max_size     = 10

  labels = {
    role         = "workload"
    capacity     = "spot"
  }

  tags = {
    WorkloadType = "non-critical"
  }
}
```

## Example: GPU Node Group

```hcl
module "eks_node_group_gpu" {
  source = "../../modules/eks-node-group"

  cluster_name           = module.eks_cluster.cluster_name
  node_group_name        = "gpu-workload"
  node_role_arn          = module.eks_cluster.node_iam_role_arn
  subnet_ids             = data.aws_subnets.selected.ids
  node_security_group_id = module.eks_cluster.node_security_group_id

  instance_types = ["g4dn.xlarge"]
  ami_type       = "AL2_x86_64_GPU"
  capacity_type  = "ON_DEMAND"

  desired_size = 1
  min_size     = 0
  max_size     = 3

  labels = {
    role         = "gpu"
    nvidia.com/gpu = "true"
  }

  # Taint to ensure only GPU workloads are scheduled
  taints = [{
    key    = "nvidia.com/gpu"
    value  = "true"
    effect = "NoSchedule"
  }]

  tags = {
    WorkloadType = "gpu"
  }
}
```

## AMI Types

Supported AMI types:
- `AL2_x86_64` - Amazon Linux 2 (x86_64)
- `AL2_x86_64_GPU` - Amazon Linux 2 with GPU support
- `AL2_ARM_64` - Amazon Linux 2 (ARM64)
- `BOTTLEROCKET_ARM_64` - Bottlerocket (ARM64)
- `BOTTLEROCKET_x86_64` - Bottlerocket (x86_64)

## High Availability Best Practices

1. **Multi-AZ Deployment**: Ensure `subnet_ids` span at least 2 AZs
2. **Minimum Node Count**: Set `min_size >= 2` for production
3. **Max Unavailable**: Default `max_unavailable = 1` prevents mass disruption
4. **Mixed Instances**: For Spot, use multiple instance types for better availability

## Notes

- Node group creation takes approximately 5-10 minutes
- The `desired_size` is ignored during updates (managed by Cluster Autoscaler)
- Launch template uses `$Latest` version for automatic updates
- IMDSv2 is enforced for security (metadata hop limit = 1)
- EBS volumes are encrypted by default
