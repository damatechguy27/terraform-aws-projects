# ==============================================================================
# Cluster Outputs
# ==============================================================================

output "cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.main.id
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = aws_eks_cluster.main.arn
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint URL"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_ca_cert" {
  description = "EKS cluster CA certificate (base64 encoded)"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "cluster_version" {
  description = "EKS cluster Kubernetes version"
  value       = aws_eks_cluster.main.version
}

output "cluster_platform_version" {
  description = "EKS cluster platform version"
  value       = aws_eks_cluster.main.platform_version
}

output "cluster_status" {
  description = "EKS cluster status"
  value       = aws_eks_cluster.main.status
}

# ==============================================================================
# OIDC Outputs (for IRSA)
# ==============================================================================

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for IRSA (with https://)"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "cluster_oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "cluster_oidc_provider_url" {
  description = "OIDC provider URL without https:// prefix (for IAM trust policies)"
  value       = local.oidc_provider_url
}

# ==============================================================================
# IAM Outputs
# ==============================================================================

output "cluster_iam_role_arn" {
  description = "IAM role ARN for EKS cluster"
  value       = aws_iam_role.cluster.arn
}

output "cluster_iam_role_name" {
  description = "IAM role name for EKS cluster"
  value       = aws_iam_role.cluster.name
}

output "node_iam_role_arn" {
  description = "IAM role ARN for EKS nodes"
  value       = aws_iam_role.node.arn
}

output "node_iam_role_name" {
  description = "IAM role name for EKS nodes"
  value       = aws_iam_role.node.name
}

output "node_iam_instance_profile_arn" {
  description = "IAM instance profile ARN for EKS nodes"
  value       = aws_iam_instance_profile.node.arn
}

output "node_iam_instance_profile_name" {
  description = "IAM instance profile name for EKS nodes"
  value       = aws_iam_instance_profile.node.name
}

# ==============================================================================
# Security Group Outputs
# ==============================================================================

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster control plane"
  value       = aws_security_group.cluster.id
}

output "node_security_group_id" {
  description = "Security group ID for EKS worker nodes"
  value       = aws_security_group.node.id
}

# ==============================================================================
# CloudWatch Outputs
# ==============================================================================

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name for cluster logs"
  value       = aws_cloudwatch_log_group.cluster.name
}

output "cloudwatch_log_group_arn" {
  description = "CloudWatch log group ARN for cluster logs"
  value       = aws_cloudwatch_log_group.cluster.arn
}

# ==============================================================================
# VPC Outputs (when VPC is created by module)
# ==============================================================================

output "vpc_id" {
  description = "VPC ID (created or provided)"
  value       = local.resolved_vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = var.vpc_create ? aws_vpc.eks[0].cidr_block : null
}

output "public_subnet_ids" {
  description = "Public subnet IDs (created or provided)"
  value       = var.vpc_create ? aws_subnet.public[*].id : null
}

output "private_subnet_ids" {
  description = "Private subnet IDs (if created)"
  value       = var.vpc_create && var.create_private_subnets ? aws_subnet.private[*].id : null
}

output "internet_gateway_id" {
  description = "Internet Gateway ID (if created)"
  value       = var.vpc_create ? aws_internet_gateway.eks[0].id : null
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs (if created)"
  value       = var.vpc_create && var.enable_nat_gateway ? aws_nat_gateway.eks[*].id : null
}
