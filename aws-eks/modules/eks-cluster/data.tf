# Get the TLS certificate for OIDC provider thumbprint
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# Get current AWS partition (aws, aws-cn, aws-us-gov)
data "aws_partition" "current" {}

# Get current AWS caller identity
data "aws_caller_identity" "current" {}

# Get current AWS region
data "aws_region" "current" {}

# ==============================================================================
# VPC Creation Support - Availability Zones
# ==============================================================================

data "aws_availability_zones" "available" {
  count = var.vpc_create ? 1 : 0
  state = "available"
}
