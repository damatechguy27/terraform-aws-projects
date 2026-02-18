# ==============================================================================
# EKS Cluster Security Group
# ==============================================================================

# Security group for EKS cluster control plane
resource "aws_security_group" "cluster" {
  name        = local.cluster_sg_name
  description = "Security group for EKS cluster control plane"
  vpc_id      = local.resolved_vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = local.cluster_sg_name
    }
  )
}

# Allow cluster to communicate with nodes on port 443 (kubelet)
resource "aws_security_group_rule" "cluster_to_node_443" {
  description              = "Allow cluster to communicate with nodes on 443"
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.node.id
  security_group_id        = aws_security_group.cluster.id
}

# Allow cluster to communicate with nodes for kubelet API
resource "aws_security_group_rule" "cluster_to_node_10250" {
  description              = "Allow cluster to communicate with nodes on kubelet port"
  type                     = "egress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.node.id
  security_group_id        = aws_security_group.cluster.id
}

# Allow cluster to communicate with nodes on ephemeral ports (for CoreDNS)
resource "aws_security_group_rule" "cluster_to_node_ephemeral" {
  description              = "Allow cluster to communicate with nodes on ephemeral ports"
  type                     = "egress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.node.id
  security_group_id        = aws_security_group.cluster.id
}

# ==============================================================================
# EKS Node Security Group
# ==============================================================================

# Security group for EKS worker nodes
resource "aws_security_group" "node" {
  name        = local.node_sg_name
  description = "Security group for EKS worker nodes"
  vpc_id      = local.resolved_vpc_id

  tags = merge(
    local.common_tags,
    {
      Name                                          = local.node_sg_name
      "kubernetes.io/cluster/${local.cluster_name}" = "owned"
    }
  )
}

# Allow nodes to communicate with each other on all ports
resource "aws_security_group_rule" "node_to_node" {
  description              = "Allow nodes to communicate with each other"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  source_security_group_id = aws_security_group.node.id
  security_group_id        = aws_security_group.node.id
}

# Allow nodes to communicate with cluster API server
resource "aws_security_group_rule" "node_to_cluster_443" {
  description              = "Allow nodes to communicate with cluster API"
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cluster.id
  security_group_id        = aws_security_group.node.id
}

# Allow nodes to reach internet (for pulling images, etc.)
resource "aws_security_group_rule" "node_egress_internet" {
  description       = "Allow nodes to reach internet"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.node.id
}

# Allow cluster to communicate with nodes on 443
resource "aws_security_group_rule" "node_from_cluster_443" {
  description              = "Allow cluster to communicate with nodes on 443"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cluster.id
  security_group_id        = aws_security_group.node.id
}

# Allow cluster to communicate with nodes on kubelet port 10250
resource "aws_security_group_rule" "node_from_cluster_10250" {
  description              = "Allow cluster to communicate with nodes on kubelet port"
  type                     = "ingress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cluster.id
  security_group_id        = aws_security_group.node.id
}

# Allow cluster to communicate with nodes on ephemeral ports
resource "aws_security_group_rule" "node_from_cluster_ephemeral" {
  description              = "Allow cluster to communicate with nodes on ephemeral ports"
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cluster.id
  security_group_id        = aws_security_group.node.id
}
