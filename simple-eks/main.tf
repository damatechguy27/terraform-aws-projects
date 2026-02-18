# eks.tf
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.eks_cluster.arn

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }
  
  vpc_config {
    //subnet_ids              = concat(aws_subnet.private[*].id, aws_subnet.public[*].id)
    subnet_ids = concat(aws_subnet.public[*].id) 
    //endpoint_private_access = true
    endpoint_public_access  = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
  ]
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  version  = var.cluster_version 
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  # subnet_ids      = aws_subnet.private[*].id
  subnet_ids      = aws_subnet.public[*].id

  capacity_type = "ON_DEMAND"

  launch_template {
    id      = aws_launch_template.eks_nodes.id
    version = "$Latest"
  }

  scaling_config {
    desired_size = 2
    max_size     = 4
    min_size     = 2
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_policies,
    aws_eks_cluster.main
  ]

  tags = {
    Name = "${var.cluster_name}-node"
  }
}

resource "aws_eks_access_entry" "eks_admin_role" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.eks_nodes.arn
  type          = "EC2_LINUX"
}
