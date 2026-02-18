# ==============================================================================
# Node Group Outputs
# ==============================================================================

output "node_group_id" {
  description = "EKS node group ID"
  value       = aws_eks_node_group.main.id
}

output "node_group_arn" {
  description = "EKS node group ARN"
  value       = aws_eks_node_group.main.arn
}

output "node_group_status" {
  description = "EKS node group status"
  value       = aws_eks_node_group.main.status
}

output "node_group_resources" {
  description = "Resources associated with the node group"
  value       = aws_eks_node_group.main.resources
}

output "autoscaling_group_name" {
  description = "Auto Scaling Group name associated with the node group"
  value       = try(aws_eks_node_group.main.resources[0].autoscaling_groups[0].name, "")
}

output "launch_template_id" {
  description = "Launch template ID"
  value       = aws_launch_template.node.id
}

output "launch_template_latest_version" {
  description = "Latest version of the launch template"
  value       = aws_launch_template.node.latest_version
}

output "node_group_name" {
  description = "Name of the node group"
  value       = aws_eks_node_group.main.node_group_name
}

output "capacity_type" {
  description = "Capacity type of the node group"
  value       = aws_eks_node_group.main.capacity_type
}

output "instance_types" {
  description = "Instance types used by the node group"
  value       = aws_eks_node_group.main.instance_types
}
