module "networking" {
  source             = "../../../../../modules/networking"
  project            = local.project_name
  environment        = local.environment
  name_prefix        = "${local.client_name}-${local.project_name}-${local.environment}"
  vpc_cidr           = "172.20.0.0/16"
  availability_zones = ["${local.region}a", "${local.region}b"]

  tags = local.common_tags
}

module "ecr_api" {
  source = "../../../../../modules/ecr"

  name = "${local.naming_prefix}-api"
  tags = local.common_tags
}

module "ecs_cluster" {
  source = "../../../../../modules/ecs-cluster"

  name                      = "${local.naming_prefix}-cluster"
  enable_container_insights = false
  default_capacity_provider = "FARGATE_SPOT" # dev default; cluster also allows FARGATE

  tags = local.common_tags
}

# Service definitions live in branch/client1/platform/env/<env>/.
# Platform stack reads this stack's outputs via terraform_remote_state.
