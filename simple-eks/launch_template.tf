resource "aws_launch_template" "eks_nodes" {
  name_prefix   = "${var.cluster_name}-node-"
  instance_type = "t3.medium"

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 40
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  # Note: user_data is not needed for EKS managed node groups
  # AWS automatically handles the bootstrap process

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.cluster_name}-node"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name = "${var.cluster_name}-node-volume"
    }
  }
}