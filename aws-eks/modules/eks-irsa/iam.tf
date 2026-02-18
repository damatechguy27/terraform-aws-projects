# ==============================================================================
# IAM Role for Service Account (IRSA)
# ==============================================================================

# Get current AWS partition
data "aws_partition" "current" {}

# IAM role with OIDC trust policy
resource "aws_iam_role" "irsa" {
  name                 = var.role_name
  description          = var.role_description != "" ? var.role_description : "IAM role for Kubernetes service account ${var.namespace}:${var.service_account_name}"
  assume_role_policy   = data.aws_iam_policy_document.irsa_assume_role.json
  max_session_duration = var.max_session_duration

  tags = merge(
    var.tags,
    {
      Name               = var.role_name
      ClusterName        = var.cluster_name
      ServiceAccountName = var.service_account_name
      Namespace          = var.namespace
      Module             = "eks-irsa"
    }
  )
}

# Trust policy for OIDC provider
data "aws_iam_policy_document" "irsa_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    # Restrict to specific service account
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
    }

    # Additional security: verify audience
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# ==============================================================================
# Attach Managed Policies
# ==============================================================================

resource "aws_iam_role_policy_attachment" "irsa" {
  count = length(var.role_policy_arns)

  policy_arn = var.role_policy_arns[count.index]
  role       = aws_iam_role.irsa.name
}

# ==============================================================================
# Inline Policy (Optional)
# ==============================================================================

resource "aws_iam_role_policy" "irsa_inline" {
  count = var.inline_policy_json != "" ? 1 : 0

  name   = var.inline_policy_name
  role   = aws_iam_role.irsa.name
  policy = var.inline_policy_json
}
