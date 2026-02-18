# ==============================================================================
# EKS Cluster Module
# ==============================================================================

module "eks_cluster" {
  source = "../../../modules/eks-cluster"

  # Project identification
  project_name      = local.project_name
  environment       = local.environment
  branch_identifier = local.branch_identifier

  # Cluster configuration
  cluster_version = var.cluster_version

  # VPC Creation - NEW: Create VPC instead of using default VPC
  vpc_create              = true
  vpc_cidr                = "10.0.0.0/16"
  availability_zone_count = 2
  create_private_subnets  = false # Public subnets only for dev

  # Network configuration - REMOVED: No longer using default VPC
  # vpc_id     = data.aws_vpc.selected.id
  # subnet_ids = data.aws_subnets.selected.ids

  # Endpoint access configuration
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = var.cluster_endpoint_private_access

  # Control plane logging
  enabled_cluster_log_types  = ["api", "audit", "authenticator"]
  cluster_log_retention_days = var.cluster_log_retention_days

  # Tags
  tags = local.common_tags
}

# ==============================================================================
# EKS Node Group (System)
# ==============================================================================

module "eks_node_group_system" {
  source = "../../../modules/eks-node-group"

  # Dependencies
  cluster_name           = module.eks_cluster.cluster_name
  node_role_arn          = module.eks_cluster.node_iam_role_arn
  subnet_ids             = module.eks_cluster.public_subnet_ids
  node_security_group_id = module.eks_cluster.node_security_group_id

  # Node group identification
  node_group_name = "${local.naming_prefix}-system"

  # Instance configuration
  instance_types = ["t3.medium"]
  ami_type       = "AL2023_x86_64_STANDARD"
  disk_size      = 40
  disk_type      = "gp3"

  # Capacity configuration
  capacity_type = "ON_DEMAND"
  desired_size  = 2
  min_size      = 2
  max_size      = 4

  # Update configuration
  max_unavailable = 1

  # Kubernetes labels
  labels = {
    role        = "system"
    environment = local.environment
    managed-by  = "terraform"
  }

  # Tags
  tags = local.common_tags
}

# ==============================================================================
# IAM Policy for AWS Load Balancer Controller
# ==============================================================================

resource "aws_iam_policy" "aws_lb_controller" {
  name        = "${local.naming_prefix}-aws-lb-controller"
  description = "IAM policy for AWS Load Balancer Controller in ${local.naming_prefix}"

  # Reference the IAM policy JSON file downloaded from AWS
  policy = file("${path.module}/aws-lb-controller-iam-policy.json")

  tags = merge(
    local.common_tags,
    {
      Name = "${local.naming_prefix}-aws-lb-controller"
    }
  )
}

# ==============================================================================
# IRSA for AWS Load Balancer Controller
# ==============================================================================

module "irsa_aws_lb_controller" {
  source = "../../../modules/eks-irsa"

  # Service account configuration
  service_account_name   = "aws-load-balancer-controller"
  namespace              = "kube-system"
  create_service_account = true

  # EKS cluster OIDC configuration
  cluster_name      = module.eks_cluster.cluster_name
  oidc_provider_arn = module.eks_cluster.cluster_oidc_provider_arn
  oidc_provider_url = replace(module.eks_cluster.cluster_oidc_issuer_url, "https://", "")

  # IAM role configuration
  role_name        = "${local.naming_prefix}-aws-lb-controller"
  role_description = "IAM role for AWS Load Balancer Controller in ${local.naming_prefix}"

  # Attach AWS Load Balancer Controller IAM policy
  role_policy_arns = [
    aws_iam_policy.aws_lb_controller.arn
  ]

  # Tags
  tags = local.common_tags
}

# ==============================================================================
# Ingress Controller (AWS Load Balancer Controller)
# ==============================================================================

module "ingress_controller" {
  source = "../../../modules/eks-ingress-controller"

  # Ensure node group is ready before deploying controller
  depends_on = [
    module.eks_node_group_system
  ]

  # Cluster configuration
  cluster_name = module.eks_cluster.cluster_name
  vpc_id       = module.eks_cluster.vpc_id

  # IRSA configuration
  service_account_role_arn = module.irsa_aws_lb_controller.iam_role_arn
  service_account_name     = "aws-load-balancer-controller"

  # Helm chart configuration
  chart_version = "1.7.1"
  namespace     = "kube-system"

  # Deployment configuration
  replica_count = 2
  log_level     = "info"

  # Feature configuration
  enable_shield = false
  enable_waf    = false
  enable_wafv2  = false

  # Deployment behavior
  wait_for_deployment = true
  timeout             = 600
}
