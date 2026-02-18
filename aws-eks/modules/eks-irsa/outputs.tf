# ==============================================================================
# IAM Role Outputs
# ==============================================================================

output "iam_role_arn" {
  description = "ARN of the IAM role for the service account"
  value       = aws_iam_role.irsa.arn
}

output "iam_role_name" {
  description = "Name of the IAM role"
  value       = aws_iam_role.irsa.name
}

output "iam_role_id" {
  description = "ID of the IAM role"
  value       = aws_iam_role.irsa.id
}

output "iam_role_unique_id" {
  description = "Unique ID of the IAM role"
  value       = aws_iam_role.irsa.unique_id
}

# ==============================================================================
# Service Account Outputs
# ==============================================================================

output "service_account_name" {
  description = "Name of the Kubernetes service account"
  value       = var.service_account_name
}

output "service_account_namespace" {
  description = "Namespace of the Kubernetes service account"
  value       = var.namespace
}

output "service_account_uid" {
  description = "UID of the Kubernetes service account (if created)"
  value       = var.create_service_account ? kubernetes_service_account_v1.irsa[0].metadata[0].uid : null
}
