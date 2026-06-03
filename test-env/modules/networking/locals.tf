locals {
  name_prefix = coalesce(var.name_prefix, "${var.project}-${var.environment}")

  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Module      = "networking"
    },
    var.tags,
  )

  public_subnets = {
    for idx, az in var.availability_zones : az => {
      az   = az
      cidr = cidrsubnet(var.vpc_cidr, 8, idx)
    }
  }

  private_subnets = {
    for idx, az in var.availability_zones : az => {
      az   = az
      cidr = cidrsubnet(var.vpc_cidr, 8, idx + 100)
    }
  }
}
