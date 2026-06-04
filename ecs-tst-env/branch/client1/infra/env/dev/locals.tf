locals {
  # Project identification
  client_name  = "client1"
  project_name = "ecs-app"
  stack        = "infra"
  environment  = "dev"
  region       = "us-west-2"

  # Naming prefix for all resources
  naming_prefix = "${local.client_name}-${local.project_name}-${local.stack}-${local.environment}"

  # Cost center for billing
  cost_center = "${local.client_name}-${local.project_name}-${local.stack}-${local.environment}"

  # Common tags applied to all resources via AWS provider default_tags
  common_tags = {
    Client      = local.client_name
    Project     = local.project_name
    Stack       = local.stack
    Environment = local.environment
    ManagedBy   = "terraform"
    CostCenter  = local.cost_center
    Region      = local.region
  }
}
