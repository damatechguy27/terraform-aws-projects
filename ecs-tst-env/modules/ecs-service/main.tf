resource "aws_cloudwatch_log_group" "this" {
  name              = local.log_group_name
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_security_group" "service" {
  name        = "${var.name_prefix}-svc-sg"
  description = "ECS service SG for ${var.name_prefix}"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-svc-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "ingress" {
  for_each = local.ingress_rules

  security_group_id = aws_security_group.service.id
  cidr_ipv4         = each.value.cidr
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  ip_protocol       = each.value.protocol
  description       = each.value.description
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.service.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all egress (ECR pulls, API calls)"
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.name_prefix
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = var.task_role_arn != null ? var.task_role_arn : aws_iam_role.task[0].arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode(local.container_definitions)

  tags = local.common_tags
}

resource "aws_ecs_service" "this" {
  name            = "${var.name_prefix}-svc"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count

  enable_execute_command = var.enable_execute_command

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = concat([aws_security_group.service.id], var.additional_security_group_ids)
    assign_public_ip = var.assign_public_ip
  }

  dynamic "capacity_provider_strategy" {
    for_each = local.capacity_provider_strategy
    content {
      capacity_provider = capacity_provider_strategy.value.capacity_provider
      weight            = capacity_provider_strategy.value.weight
      base              = capacity_provider_strategy.value.base
    }
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  lifecycle {
    # Ignore desired_count so app autoscaling won't fight Terraform.
    ignore_changes = [desired_count]
  }

  tags = local.common_tags
}
