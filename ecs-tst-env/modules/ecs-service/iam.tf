data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Execution role — used by the ECS agent to pull images, write logs, fetch secrets.
resource "aws_iam_role" "execution" {
  name               = "${var.name_prefix}-task-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Allow the execution role to read the configured secrets (SSM + Secrets Manager).
data "aws_iam_policy_document" "execution_secrets" {
  count = length(var.container_secrets) > 0 ? 1 : 0

  statement {
    actions = [
      "ssm:GetParameters",
      "secretsmanager:GetSecretValue",
      "kms:Decrypt",
    ]
    resources = [for s in var.container_secrets : s.valueFrom]
  }
}

resource "aws_iam_role_policy" "execution_secrets" {
  count = length(var.container_secrets) > 0 ? 1 : 0

  name   = "${var.name_prefix}-execution-secrets"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution_secrets[0].json
}

# Task role — assumed by the application code at runtime. Empty by default; attach
# policies in the calling stack via aws_iam_role_policy_attachment targeting this role.
resource "aws_iam_role" "task" {
  count = var.task_role_arn == null ? 1 : 0

  name               = "${var.name_prefix}-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
  tags               = local.common_tags
}

# ECS Exec permissions on the task role.
data "aws_iam_policy_document" "exec_command" {
  count = var.enable_execute_command && var.task_role_arn == null ? 1 : 0

  statement {
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "exec_command" {
  count = var.enable_execute_command && var.task_role_arn == null ? 1 : 0

  name   = "${var.name_prefix}-exec-command"
  role   = aws_iam_role.task[0].id
  policy = data.aws_iam_policy_document.exec_command[0].json
}
