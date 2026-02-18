# ==============================================================================
# Kubernetes Service Account with IAM Role Annotation
# ==============================================================================

resource "kubernetes_service_account_v1" "irsa" {
  count = var.create_service_account ? 1 : 0

  metadata {
    name      = var.service_account_name
    namespace = var.namespace

    # Annotation to link service account with IAM role
    annotations = merge(
      var.service_account_annotations,
      {
        "eks.amazonaws.com/role-arn" = aws_iam_role.irsa.arn
      }
    )

    labels = merge(
      var.service_account_labels,
      {
        "app.kubernetes.io/managed-by" = "terraform"
        "app.kubernetes.io/name"       = var.service_account_name
      }
    )
  }

  # Automatically mount service account token
  automount_service_account_token = true
}
