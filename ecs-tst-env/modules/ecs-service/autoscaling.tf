# Application Auto Scaling for the ECS service.
# Enabled only when both min_count and max_count are set (local.autoscaling_enabled).
# The service's desired_count is ignored after creation (see aws_ecs_service lifecycle),
# so the scaler owns the running task count between min and max.

resource "aws_appautoscaling_target" "this" {
  count = local.autoscaling_enabled ? 1 : 0

  max_capacity       = var.max_count
  min_capacity       = var.min_count
  resource_id        = "service/${local.cluster_name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  lifecycle {
    precondition {
      condition     = var.min_count <= var.max_count
      error_message = "min_count must be <= max_count."
    }
    precondition {
      condition     = var.desired_count >= var.min_count && var.desired_count <= var.max_count
      error_message = "desired_count must be within [min_count, max_count]."
    }
  }
}

# Target-tracking on average CPU utilization. ECS adjusts desired_count to keep CPU
# near var.autoscaling_cpu_target.
resource "aws_appautoscaling_policy" "cpu" {
  count = local.autoscaling_enabled ? 1 : 0

  name               = "${var.name_prefix}-cpu-target-tracking"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = var.autoscaling_cpu_target
    scale_out_cooldown = var.autoscaling_scale_out_cooldown
    scale_in_cooldown  = var.autoscaling_scale_in_cooldown
  }
}
