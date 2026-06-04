module "ecs_service_api" {
  source = "../../../../../modules/ecs-service"

  name_prefix = "${local.naming_prefix}-api"
  cluster_id  = data.terraform_remote_state.infra.outputs.ecs_cluster_id

  vpc_id     = data.terraform_remote_state.infra.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.infra.outputs.public_subnet_ids # public + assign_public_ip for cheap dev (no NAT)

  assign_public_ip = true
  ingress_cidrs    = ["0.0.0.0/0"] # dev only — front with an ALB for prod

  container_image = "${data.terraform_remote_state.infra.outputs.ecr_api_repository_url}:${var.container_image_tag}"
  container_port  = 80

  desired_count    = 2 # 2 tasks across AZs for HA
  task_cpu         = 256
  task_memory      = 512
  use_fargate_spot = true # dev — flip off for prod

  log_retention_days = 14

  tags = local.common_tags
}
