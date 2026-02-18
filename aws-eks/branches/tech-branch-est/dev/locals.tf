locals {
  # Project identification
  project_name      = "eks-platform"
  environment       = "dev"
  branch_identifier = "est"

  # Naming prefix for all resources
  naming_prefix = "${local.project_name}-${local.branch_identifier}-${local.environment}"

  # Cost center for billing
  cost_center = "engineering"

  # Common tags applied to all resources via AWS provider default_tags
  common_tags = {
    Project     = local.project_name
    Environment = local.environment
    Branch      = local.branch_identifier
    ManagedBy   = "terraform"
    CostCenter  = local.cost_center
    Region      = var.aws_region
  }
}
