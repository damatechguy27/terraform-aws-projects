# ==============================================================================
# VPC Data Sources - NOT NEEDED when vpc_create = true
# ==============================================================================

# # Lookup default VPC
# data "aws_vpc" "selected" {
#   default = true
# }
#
# # Get all subnets in the default VPC
# data "aws_subnets" "selected" {
#   filter {
#     name   = "vpc-id"
#     values = [data.aws_vpc.selected.id]
#   }
# }
#
# # Get subnet details to verify AZ distribution
# data "aws_subnet" "selected" {
#   for_each = toset(data.aws_subnets.selected.ids)
#   id       = each.value
# }

# ==============================================================================
# Availability Zone Data
# ==============================================================================

# Get available availability zones in the region
data "aws_availability_zones" "available" {
  state = "available"
}

# ==============================================================================
# Account Data
# ==============================================================================

# Get current AWS caller identity
data "aws_caller_identity" "current" {}

# Get current AWS region
data "aws_region" "current" {}
