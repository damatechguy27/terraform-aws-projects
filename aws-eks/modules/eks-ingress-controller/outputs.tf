# ==============================================================================
# Helm Release Outputs
# ==============================================================================

output "release_name" {
  description = "Name of the Helm release"
  value       = helm_release.aws_lb_controller.name
}

output "release_namespace" {
  description = "Namespace of the Helm release"
  value       = helm_release.aws_lb_controller.namespace
}

output "release_status" {
  description = "Status of the Helm release"
  value       = helm_release.aws_lb_controller.status
}

output "release_version" {
  description = "Version of the Helm release"
  value       = helm_release.aws_lb_controller.version
}

output "release_chart" {
  description = "Chart name of the Helm release"
  value       = helm_release.aws_lb_controller.chart
}

output "service_account_name" {
  description = "Name of the service account used by the controller"
  value       = var.service_account_name
}
