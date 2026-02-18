# ==============================================================================
# CloudWatch Log Group for EKS Control Plane Logs
# ==============================================================================

resource "aws_cloudwatch_log_group" "cluster" {
  name              = local.log_group_name
  retention_in_days = var.cluster_log_retention_days

  tags = merge(
    local.common_tags,
    {
      Name = local.log_group_name
    }
  )
}

# ==============================================================================
# EKS Cluster
# ==============================================================================

resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  vpc_config {
    subnet_ids              = local.resolved_subnet_ids
    endpoint_private_access = var.cluster_endpoint_private_access
    endpoint_public_access  = var.cluster_endpoint_public_access
    public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
    security_group_ids      = [aws_security_group.cluster.id]
  }

  enabled_cluster_log_types = var.enabled_cluster_log_types

  # Optional: Encryption configuration for Kubernetes secrets
  dynamic "encryption_config" {
    for_each = var.cluster_encryption_config_enable ? [1] : []

    content {
      provider {
        key_arn = var.cluster_encryption_config_kms_key_id
      }

      resources = ["secrets"]
    }
  }

  # Optional: Custom service CIDR
  dynamic "kubernetes_network_config" {
    for_each = var.cluster_service_ipv4_cidr != null ? [1] : []

    content {
      service_ipv4_cidr = var.cluster_service_ipv4_cidr
    }
  }

  tags = local.common_tags

  # Ensure IAM role and CloudWatch log group are created first
  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_iam_role_policy_attachment.cluster_vpc_resource_controller,
    aws_cloudwatch_log_group.cluster
  ]

  # Prevent accidental cluster deletion
  lifecycle {
    ignore_changes = [
      # Ignore changes to version during plan (upgrade separately)
    ]
  }
}

# ==============================================================================
# OIDC Provider for IRSA (IAM Roles for Service Accounts)
# ==============================================================================

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = merge(
    local.common_tags,
    {
      Name = "${local.cluster_name}-oidc-provider"
    }
  )
}

# ==============================================================================
# EKS Access Entry for Node Role
# ==============================================================================

# Grant node IAM role access to the cluster using EKS Access Entry API
resource "aws_eks_access_entry" "node" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.node.arn
  type          = "EC2_LINUX"

  tags = merge(
    local.common_tags,
    {
      Name = "${local.cluster_name}-node-access-entry"
    }
  )
}
