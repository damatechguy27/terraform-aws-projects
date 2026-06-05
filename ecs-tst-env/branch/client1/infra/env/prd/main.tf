module "networking" {
  source             = "../../../../modules/networking"
  project            = local.project_name
  environment        = local.environment
  name_prefix        = "${local.client_name}-${local.project_name}-${local.environment}"
  vpc_cidr           = "172.21.0.0/16"
  availability_zones = ["${local.region}a", "${local.region}b"]

  tags = local.common_tags
}
