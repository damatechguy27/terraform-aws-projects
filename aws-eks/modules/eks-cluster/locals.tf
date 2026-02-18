locals {
  # Naming convention: {project}-{branch}-{environment}-{resource}
  naming_prefix = "${var.project_name}-${var.branch_identifier}-${var.environment}"
  cluster_name  = "${local.naming_prefix}-eks"

  # Common tags applied to all resources
  common_tags = merge(
    var.tags,
    {
      Name        = local.cluster_name
      ClusterName = local.cluster_name
      Module      = "eks-cluster"
    }
  )

  # Tags required for AWS Load Balancer Controller to discover subnets
  # These tags must be applied to subnets (done at VPC level, not here)
  subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  # Security group name prefixes
  cluster_sg_name = "${local.cluster_name}-cluster-sg"
  node_sg_name    = "${local.cluster_name}-node-sg"

  # IAM role names
  cluster_role_name = "${local.cluster_name}-cluster-role"
  node_role_name    = "${local.cluster_name}-node-role"

  # CloudWatch log group name
  log_group_name = "/aws/eks/${local.cluster_name}/cluster"

  # OIDC provider URL without https:// prefix
  oidc_provider_url = replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")

  # ==============================================================================
  # Resolved VPC and Subnet IDs (from created or provided)
  # ==============================================================================

  resolved_vpc_id     = var.vpc_create ? aws_vpc.eks[0].id : var.vpc_id
  resolved_subnet_ids = var.vpc_create ? aws_subnet.public[*].id : var.subnet_ids
}
