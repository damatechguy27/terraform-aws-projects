# One ECS service per app (see local.services). Each service pulls the latest image
# from the shared repo matching its image_prefix, resolved by data.external.latest_image.
module "ecs_service" {
  source   = "../../../../../modules/ecs-service"
  for_each = local.services

  name_prefix = "${local.naming_prefix}-${each.key}"
  cluster_id  = data.terraform_remote_state.infra.outputs.ecs_cluster_id

  vpc_id     = data.terraform_remote_state.infra.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.infra.outputs.public_subnet_ids # public + assign_public_ip for cheap dev (no NAT)

  assign_public_ip = true
  ingress_rules    = each.value.ingress_rules # per-app SG openings

  container_image = "${local.api_repo_url}:${data.external.latest_image[each.key].result.tag}"
  container_port  = each.value.container_port

  # Per-app sizing
  task_cpu    = each.value.task_cpu
  task_memory = each.value.task_memory

  # Per-app task count + CPU step autoscaling. Any autoscaling_* field omitted from an app's
  # local.services entry is passed as null, so the module default applies (try -> null).
  desired_count = each.value.desired_count
  min_count     = each.value.min_count
  max_count     = each.value.max_count

  # Scale out (CPU high)
  autoscaling_high_threshold           = try(each.value.autoscaling_high_threshold, null)
  autoscaling_high_period              = try(each.value.autoscaling_high_period, null)
  autoscaling_high_evaluation_periods  = try(each.value.autoscaling_high_evaluation_periods, null)
  autoscaling_high_datapoints_to_alarm = try(each.value.autoscaling_high_datapoints_to_alarm, null)
  autoscaling_scale_out_adjustment     = try(each.value.autoscaling_scale_out_adjustment, null)
  autoscaling_scale_out_cooldown       = try(each.value.autoscaling_scale_out_cooldown, null)

  # Scale in (CPU low)
  autoscaling_low_threshold           = try(each.value.autoscaling_low_threshold, null)
  autoscaling_low_period              = try(each.value.autoscaling_low_period, null)
  autoscaling_low_evaluation_periods  = try(each.value.autoscaling_low_evaluation_periods, null)
  autoscaling_low_datapoints_to_alarm = try(each.value.autoscaling_low_datapoints_to_alarm, null)
  autoscaling_scale_in_adjustment     = try(each.value.autoscaling_scale_in_adjustment, null)
  autoscaling_scale_in_cooldown       = try(each.value.autoscaling_scale_in_cooldown, null)

  use_fargate_spot = true # dev — flip off for prod

  log_retention_days = 14

  tags = local.common_tags
}
