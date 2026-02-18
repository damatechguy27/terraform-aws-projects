# ==============================================================================
# EKS Cluster IAM Role
# ==============================================================================

# IAM role for EKS cluster
resource "aws_iam_role" "cluster" {
  name               = local.cluster_role_name
  assume_role_policy = data.aws_iam_policy_document.cluster_assume_role.json

  tags = merge(
    local.common_tags,
    {
      Name = local.cluster_role_name
    }
  )
}

# Trust policy for EKS cluster
data "aws_iam_policy_document" "cluster_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# Attach required AWS managed policy for EKS cluster
resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# Optional: Attach VPC resource controller policy for security group management
resource "aws_iam_role_policy_attachment" "cluster_vpc_resource_controller" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster.name
}

# ==============================================================================
# EKS Node IAM Role
# ==============================================================================

# IAM role for EKS nodes
resource "aws_iam_role" "node" {
  name               = local.node_role_name
  assume_role_policy = data.aws_iam_policy_document.node_assume_role.json

  tags = merge(
    local.common_tags,
    {
      Name = local.node_role_name
    }
  )
}

# Trust policy for EKS nodes
data "aws_iam_policy_document" "node_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# Attach required AWS managed policies for EKS nodes

# Worker node policy - core permissions for nodes to join cluster
resource "aws_iam_role_policy_attachment" "node_worker_policy" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

# CNI policy - allows nodes to manage network interfaces
resource "aws_iam_role_policy_attachment" "node_cni_policy" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node.name
}

# Container registry policy - allows pulling images from ECR
resource "aws_iam_role_policy_attachment" "node_ecr_readonly" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}

# SSM policy - allows Session Manager access to nodes (optional but recommended)
resource "aws_iam_role_policy_attachment" "node_ssm_policy" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.node.name
}

# Load balancing policy - allows managing load balancers for services
resource "aws_iam_role_policy_attachment" "node_load_balancing_policy" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSLoadBalancingPolicy"
  role       = aws_iam_role.node.name
}

# S3 read-only policy - allows pulling artifacts and configurations from S3
resource "aws_iam_role_policy_attachment" "node_s3_readonly" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonS3ReadOnlyAccess"
  role       = aws_iam_role.node.name
}

# ==============================================================================
# IAM Instance Profile for Nodes
# ==============================================================================

# Instance profile for EC2 instances (required for managed node groups)
resource "aws_iam_instance_profile" "node" {
  name = "${local.node_role_name}-instance-profile"
  role = aws_iam_role.node.name

  tags = merge(
    local.common_tags,
    {
      Name = "${local.node_role_name}-instance-profile"
    }
  )
}
