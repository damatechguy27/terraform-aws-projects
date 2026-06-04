output "service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.this.name
}

output "service_id" {
  description = "ECS service ID/ARN."
  value       = aws_ecs_service.this.id
}

output "task_definition_arn" {
  description = "Latest task definition ARN."
  value       = aws_ecs_task_definition.this.arn
}

output "task_definition_family" {
  description = "Task definition family (stable across revisions)."
  value       = aws_ecs_task_definition.this.family
}

output "execution_role_arn" {
  description = "ARN of the task execution role."
  value       = aws_iam_role.execution.arn
}

output "task_role_arn" {
  description = "ARN of the task role (the role the container assumes at runtime)."
  value       = var.task_role_arn != null ? var.task_role_arn : aws_iam_role.task[0].arn
}

output "task_role_name" {
  description = "Name of the auto-created task role, for attaching extra policies. Null if task_role_arn was provided."
  value       = var.task_role_arn == null ? aws_iam_role.task[0].name : null
}

output "security_group_id" {
  description = "Security group attached to the service tasks."
  value       = aws_security_group.service.id
}

output "log_group_name" {
  description = "CloudWatch log group for the service."
  value       = aws_cloudwatch_log_group.this.name
}
