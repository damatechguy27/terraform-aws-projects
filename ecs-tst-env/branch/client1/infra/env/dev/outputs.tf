output "vpc_id" {
  description = "ID of the dev VPC."
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs (ordered by AZ)."
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs (ordered by AZ)."
  value       = module.networking.private_subnet_ids
}

output "ecs_cluster_id" {
  description = "ECS cluster ID (ARN) for the platform stack to attach services to."
  value       = module.ecs_cluster.cluster_id
}

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = module.ecs_cluster.cluster_name
}

output "ecr_api_repository_url" {
  description = "ECR repo URL for the api service. Consumed by services/deploy.sh and the platform stack."
  value       = module.ecr_api.repository_url
}
