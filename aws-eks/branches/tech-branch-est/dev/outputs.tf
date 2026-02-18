# ==============================================================================
# Cluster Outputs
# ==============================================================================

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks_cluster.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks_cluster.cluster_endpoint
}

output "cluster_version" {
  description = "Kubernetes version running on the cluster"
  value       = module.eks_cluster.cluster_version
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks_cluster.cluster_arn
}

output "cluster_status" {
  description = "EKS cluster status"
  value       = module.eks_cluster.cluster_status
}

# ==============================================================================
# Configuration Outputs
# ==============================================================================

output "cluster_region" {
  description = "AWS region where the cluster is deployed"
  value       = var.aws_region
}

output "configure_kubectl" {
  description = "Command to configure kubectl to access the cluster"
  value       = "aws eks update-kubeconfig --name ${module.eks_cluster.cluster_name} --region ${var.aws_region}"
}

# ==============================================================================
# OIDC Provider Outputs
# ==============================================================================

output "oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  value       = module.eks_cluster.cluster_oidc_provider_arn
}

output "oidc_provider_url" {
  description = "OIDC provider URL (without https://)"
  value       = module.eks_cluster.cluster_oidc_provider_url
}

# ==============================================================================
# Node Group Outputs
# ==============================================================================

output "node_group_system_id" {
  description = "System node group ID"
  value       = module.eks_node_group_system.node_group_id
}

output "node_group_system_status" {
  description = "System node group status"
  value       = module.eks_node_group_system.node_group_status
}

# ==============================================================================
# Ingress Controller Outputs
# ==============================================================================

output "ingress_controller_status" {
  description = "AWS Load Balancer Controller deployment status"
  value       = module.ingress_controller.release_status
}

output "ingress_controller_version" {
  description = "AWS Load Balancer Controller chart version"
  value       = module.ingress_controller.release_version
}

# ==============================================================================
# VPC Information Outputs
# ==============================================================================

output "vpc_id" {
  description = "VPC ID used by the cluster"
  value       = module.eks_cluster.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = module.eks_cluster.vpc_cidr
}

output "subnet_ids" {
  description = "Public subnet IDs used by the cluster"
  value       = module.eks_cluster.public_subnet_ids
}
