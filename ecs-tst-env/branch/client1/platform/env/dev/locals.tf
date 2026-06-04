locals {
  client_name  = "client1"
  project_name = "infra" # keep aligned with the infra stack so resource names match (e.g. cluster + service share "client1-infra-dev" prefix)
  stack        = "platform"
  environment  = "dev"
  region       = "us-west-2"

  naming_prefix = "${local.client_name}-${local.project_name}-${local.environment}"

  cost_center = "infra-${local.environment}"

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
