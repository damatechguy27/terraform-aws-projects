# Application Auto Scaling for the ECS service.
# Enabled only when both min_count and max_count are set (local.autoscaling_enabled).
# The service's desired_count is ignored after creation (see aws_ecs_service lifecycle),
# so the scaler owns the running task count between min and max.
#
# Scaling type: STEP scaling driven by two CloudWatch CPU alarms.
#   scale OUT: +autoscaling_scale_out_adjustment task(s) when CPU is high
#   scale IN : -autoscaling_scale_in_adjustment  task(s) when CPU is low

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

# --- Scale OUT --------------------------------------------------------------------------
resource "aws_appautoscaling_policy" "scale_out" {
  count = local.autoscaling_enabled ? 1 : 0

  name               = "${var.name_prefix}-scale-out"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = var.autoscaling_scale_out_cooldown
    metric_aggregation_type = "Average"

    # CPU above threshold -> add tasks. Unbounded upper step.
    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = var.autoscaling_scale_out_adjustment
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  count = local.autoscaling_enabled ? 1 : 0

  alarm_name        = "${var.name_prefix}-cpu-high"
  alarm_description = "Scale out ${var.name_prefix}: CPU >= ${var.autoscaling_high_threshold}% on ${var.autoscaling_high_datapoints_to_alarm} of ${var.autoscaling_high_evaluation_periods} datapoints (${var.autoscaling_high_period}s each)."

  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.autoscaling_high_threshold
  period              = var.autoscaling_high_period
  evaluation_periods  = var.autoscaling_high_evaluation_periods
  datapoints_to_alarm = var.autoscaling_high_datapoints_to_alarm
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = local.cluster_name
    ServiceName = aws_ecs_service.this.name
  }

  alarm_actions = [aws_appautoscaling_policy.scale_out[0].arn]
  tags          = local.common_tags
}

# --- Scale IN ---------------------------------------------------------------------------
resource "aws_appautoscaling_policy" "scale_in" {
  count = local.autoscaling_enabled ? 1 : 0

  name               = "${var.name_prefix}-scale-in"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = var.autoscaling_scale_in_cooldown
    metric_aggregation_type = "Average"

    # CPU below threshold -> remove tasks. Unbounded lower step.
    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -var.autoscaling_scale_in_adjustment
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  count = local.autoscaling_enabled ? 1 : 0

  alarm_name        = "${var.name_prefix}-cpu-low"
  alarm_description = "Scale in ${var.name_prefix}: CPU < ${var.autoscaling_low_threshold}% on ${var.autoscaling_low_datapoints_to_alarm} of ${var.autoscaling_low_evaluation_periods} datapoints (${var.autoscaling_low_period}s each)."

  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  comparison_operator = "LessThanThreshold"
  threshold           = var.autoscaling_low_threshold
  period              = var.autoscaling_low_period
  evaluation_periods  = var.autoscaling_low_evaluation_periods
  datapoints_to_alarm = var.autoscaling_low_datapoints_to_alarm
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = local.cluster_name
    ServiceName = aws_ecs_service.this.name
  }

  alarm_actions = [aws_appautoscaling_policy.scale_in[0].arn]
  tags          = local.common_tags
}
