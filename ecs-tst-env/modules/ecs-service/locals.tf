locals {
  common_tags = merge(var.tags, {
    Module = "ecs-service"
  })

  log_group_name = "/ecs/${var.name_prefix}"

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
