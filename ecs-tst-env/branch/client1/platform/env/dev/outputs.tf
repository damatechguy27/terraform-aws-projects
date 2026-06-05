output "service_names" {
  description = "Map of app key -> ECS service name."
  value       = { for k, m in module.ecs_service : k => m.service_name }
}

output "deployed_images" {
  description = "Map of app key -> the resolved image reference each service is deployed with."
  value       = { for k, d in data.external.latest_image : k => "${local.api_repo_url}:${d.result.tag}" }
}

output "security_group_ids" {
  description = "Map of app key -> service security group ID."
  value       = { for k, m in module.ecs_service : k => m.security_group_id }
}
