# ==============================================================================
# Launch Template for EKS Nodes
# ==============================================================================

resource "aws_launch_template" "node" {
  name_prefix = "${var.node_group_name}-"
  description = "Launch template for ${var.node_group_name}"

  # Block device mapping for root volume
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.disk_size
      volume_type           = var.disk_type
      delete_on_termination = true
      encrypted             = true
    }
  }

  # Monitoring configuration
  monitoring {
    enabled = var.enable_monitoring
  }

  # Note: Network interfaces block removed to allow subnet's MapPublicIpOnLaunch setting
  # to take effect. Security groups are managed by EKS node group resource automatically.

  # Metadata options (IMDSv2)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # Enforce IMDSv2
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  # User data for custom configurations (if needed)
  user_data = local.user_data != "" ? base64encode(local.user_data) : null

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      local.common_tags,
      {
        Name = "${var.node_group_name}-node"
      }
    )
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(
      local.common_tags,
      {
        Name = "${var.node_group_name}-volume"
      }
    )
  }

  tag_specifications {
    resource_type = "network-interface"
    tags = merge(
      local.common_tags,
      {
        Name = "${var.node_group_name}-eni"
      }
    )
  }

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

# ==============================================================================
# EKS Managed Node Group
# ==============================================================================

resource "aws_eks_node_group" "main" {
  cluster_name    = var.cluster_name
  node_group_name = var.node_group_name
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids

  # Scaling configuration
  scaling_config {
    desired_size = var.desired_size
    min_size     = var.min_size
    max_size     = var.max_size
  }

  # Update configuration for rolling updates
  update_config {
    max_unavailable = var.max_unavailable
  }

  # Launch template configuration
  launch_template {
    id      = aws_launch_template.node.id
    version = "$Latest"
  }

  # Instance types
  instance_types = var.instance_types

  # AMI type
  ami_type = var.ami_type

  # Capacity type (ON_DEMAND or SPOT)
  capacity_type = var.capacity_type

  # Kubernetes labels
  labels = var.labels

  # Kubernetes taints
  dynamic "taint" {
    for_each = var.taints

    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  tags = local.common_tags

  # Ensure proper creation order
  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      scaling_config[0].desired_size # Allow autoscaler to manage desired size
    ]
  }
}
