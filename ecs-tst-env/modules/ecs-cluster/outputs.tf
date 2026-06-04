output "cluster_id" {
  description = "Cluster ID (ARN). Wait on this output to ensure capacity providers are wired before creating services."
  value       = aws_ecs_cluster.this.id

  # Force consumers (services) to wait for capacity providers to be registered.
  depends_on = [aws_ecs_cluster_capacity_providers.this]
}

output "cluster_arn" {
  description = "Cluster ARN."
  value       = aws_ecs_cluster.this.arn
  depends_on  = [aws_ecs_cluster_capacity_providers.this]
}

output "cluster_name" {
  description = "Cluster name."
  value       = aws_ecs_cluster.this.name
  depends_on  = [aws_ecs_cluster_capacity_providers.this]
}
