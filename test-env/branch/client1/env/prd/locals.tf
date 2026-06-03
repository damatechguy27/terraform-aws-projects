locals {
  # Project identification
  client_name      = "client1"
  project_name      = "infra"
  project_name2      = "new-infra2"
  environment       = "prd"
  region            = "us-east-2"

  # Naming prefix for all resources
  naming_prefix = "${local.client_name}-${local.project_name}-${local.environment}"

  # Cost center for billing
  cost_center = "infra-${local.environment}"

  # Common tags applied to all resources via AWS provider default_tags
  common_tags = {
    Client      = local.client_name
    Project     = local.project_name
    Environment = local.environment
    ManagedBy   = "terraform"
    CostCenter  = local.cost_center
    Region      = local.region
  }
}
