locals {
  # Common tags for all resources
  common_tags = merge(
    var.tags,
    {
      Name          = var.node_group_name
      ClusterName   = var.cluster_name
      Module        = "eks-node-group"
      NodeGroupName = var.node_group_name
      CapacityType  = var.capacity_type
    }
  )

  # User data for node bootstrap (empty for managed node groups - EKS handles this)
  # Custom user data can be added here if needed for special configurations
  user_data = ""
}
