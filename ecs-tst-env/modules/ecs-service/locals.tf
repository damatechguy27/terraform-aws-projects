locals {
  common_tags = merge(var.tags, {
    Module = "ecs-service"
  })

  log_group_name = "/ecs/${var.name_prefix}"

  # Normalize ingress rules into a keyed map for stable for_each addresses.
  # Key = cidr + protocol + port range, so the same opening isn't duplicated.
  ingress_rules = {
    for r in var.ingress_rules :
    "${r.cidr}-${coalesce(r.protocol, "tcp")}-${r.from_port}-${r.to_port}" => {
      cidr        = r.cidr
      from_port   = r.from_port
      to_port     = r.to_port
      protocol    = coalesce(r.protocol, "tcp")
      description = coalesce(r.description, "${coalesce(r.protocol, "tcp")}/${r.from_port}-${r.to_port} from ${r.cidr}")
    }
  }

  # Autoscaling is on only when both bounds are provided.
  autoscaling_enabled = var.min_count != null && var.max_count != null

  # Application Auto Scaling resource_id needs the cluster *name*; var.cluster_id is the ARN
  # (arn:aws:ecs:...:cluster/<name>), so take the segment after the last slash.
  cluster_name = element(split("/", var.cluster_id), length(split("/", var.cluster_id)) - 1)

  container_definitions = [
    {
      name      = var.name_prefix
      image     = var.container_image
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        },
      ]

      environment = var.container_environment
      secrets     = var.container_secrets

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = local.log_group_name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "app"
        }
      }
    },
  ]

  capacity_provider_strategy = var.use_fargate_spot ? [
    { capacity_provider = "FARGATE_SPOT", weight = 1, base = 0 },
    ] : [
    { capacity_provider = "FARGATE", weight = 1, base = 0 },
  ]
}
