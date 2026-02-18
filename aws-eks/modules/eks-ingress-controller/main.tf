# ==============================================================================
# AWS Load Balancer Controller Helm Release
# ==============================================================================

resource "helm_release" "aws_lb_controller" {
  name       = var.release_name
  repository = var.chart_repository
  chart      = var.chart_name
  version    = var.chart_version
  namespace  = var.namespace

  create_namespace = var.create_namespace
  wait             = var.wait_for_deployment
  timeout          = var.timeout

  # Core configuration values
  values = [
    yamlencode({
      # Cluster identification
      clusterName = var.cluster_name
      vpcId       = var.vpc_id

      # Service account configuration (IRSA)
      # Note: Service account is created by the IRSA module, not by Helm
      serviceAccount = {
        create = false  # Changed to false - IRSA module creates the service account
        name   = var.service_account_name
        annotations = {
          "eks.amazonaws.com/role-arn" = var.service_account_role_arn
        }
      }

      # Deployment configuration
      replicaCount = var.replica_count

      # Resource configuration
      resources = {
        limits = {
          cpu    = "200m"
          memory = "500Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "200Mi"
        }
      }

      # Pod disruption budget for HA
      podDisruptionBudget = {
        maxUnavailable = 1
      }

      # Security context
      securityContext = {
        runAsNonRoot = true
        runAsUser    = 65534
        fsGroup      = 65534
      }

      # Controller configuration
      enableShield = var.enable_shield
      enableWaf    = var.enable_waf
      enableWafv2  = var.enable_wafv2

      # Logging
      logLevel = var.log_level

      # Region auto-detection (uses node's region)
      region = null

      # Feature gates (enable new features)
      enableCertManager    = false
      enableEndpointSlices = true
    })
  ]

  # Apply any custom overrides
  dynamic "set" {
    for_each = var.helm_values_overrides != "" ? [1] : []
    content {
      name  = "custom"
      value = var.helm_values_overrides
      type  = "string"
    }
  }
}
