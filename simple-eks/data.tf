# ==============================================================================
# Account and Region Data
# ==============================================================================

# Get current AWS account ID (used for IAM policies)
data "aws_caller_identity" "current" {}

# Get current AWS region
data "aws_region" "current" {}

