variable "project" {
  description = "Project name, used for resource naming and tagging."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, stg, prd)."
  type        = string

  validation {
    condition     = contains(["dev", "stg", "prd"], var.environment)
    error_message = "environment must be one of: dev, stg, prd."
  }
}

variable "name_prefix" {
  description = "Optional override for the resource name prefix. Defaults to '<project>-<environment>'."
  type        = string
  default     = null
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC. Must be a /16 to /20 to leave room for /24 subnets."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "availability_zones" {
  description = "List of exactly 2 AZs to deploy subnets into. Must belong to the provider's region."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "Provide exactly 2 availability zones for HA."
  }
}

variable "tags" {
  description = "Additional tags applied to every resource in this module."
  type        = map(string)
  default     = {}
}
