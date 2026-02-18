variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  validation {
    condition     = length(var.project_name) > 0 && length(var.project_name) <= 32
    error_message = "Project name must be between 1 and 32 characters"
  }
}

variable "environment" {
  description = "Environment name (dev, stg, prd)"
  type        = string
  validation {
    condition     = contains(["dev", "stg", "prd"], var.environment)
    error_message = "Environment must be dev, stg, or prd"
  }
}

variable "branch_identifier" {
  description = "Branch identifier (est, wst)"
  type        = string
  validation {
    condition     = length(var.branch_identifier) > 0 && length(var.branch_identifier) <= 8
    error_message = "Branch identifier must be between 1 and 8 characters"
  }
}

variable "cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.35"
  validation {
    condition     = can(regex("^1\\.(2[7-9]|[3-9][0-9])$", var.cluster_version))
    error_message = "Cluster version must be 1.27 or higher"
  }
}

variable "vpc_id" {
  description = "VPC ID where EKS cluster will be deployed (required when vpc_create = false)"
  type        = string
  default     = null

  validation {
    condition     = var.vpc_id == null || can(regex("^vpc-", var.vpc_id))
    error_message = "vpc_id must start with 'vpc-' or be null when vpc_create = true"
  }
}

variable "subnet_ids" {
  description = "List of subnet IDs for EKS cluster (required when vpc_create = false, minimum 2 subnets in different AZs)"
  type        = list(string)
  default     = null

  validation {
    condition     = var.subnet_ids == null || length(var.subnet_ids) >= 2
    error_message = "subnet_ids must contain at least 2 subnets for high availability"
  }
}

variable "cluster_endpoint_public_access" {
  description = "Enable public access to cluster endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_private_access" {
  description = "Enable private access to cluster endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks that can access the public endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enabled_cluster_log_types" {
  description = "List of control plane log types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  validation {
    condition = alltrue([
      for log_type in var.enabled_cluster_log_types :
      contains(["api", "audit", "authenticator", "controllerManager", "scheduler"], log_type)
    ])
    error_message = "Invalid log type. Must be one of: api, audit, authenticator, controllerManager, scheduler"
  }
}

variable "cluster_log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.cluster_log_retention_days)
    error_message = "Invalid log retention period. Must be a valid CloudWatch retention value"
  }
}

variable "cluster_encryption_config_enable" {
  description = "Enable encryption of Kubernetes secrets using KMS"
  type        = bool
  default     = false
}

variable "cluster_encryption_config_kms_key_id" {
  description = "KMS key ID for encrypting Kubernetes secrets"
  type        = string
  default     = ""
}

variable "cluster_service_ipv4_cidr" {
  description = "The CIDR block to assign Kubernetes service IP addresses from"
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# ==============================================================================
# VPC Creation Configuration
# ==============================================================================

variable "vpc_create" {
  description = "Create a new VPC for the cluster (false = use existing VPC via vpc_id and subnet_ids)"
  type        = bool
  default     = false
}

variable "vpc_cidr" {
  description = "CIDR block for VPC (only used when vpc_create = true)"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(regex("^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}/[0-9]{1,2}$", var.vpc_cidr))
    error_message = "vpc_cidr must be a valid CIDR block"
  }
}

variable "availability_zone_count" {
  description = "Number of availability zones to use (only when vpc_create = true)"
  type        = number
  default     = 2

  validation {
    condition     = var.availability_zone_count >= 2 && var.availability_zone_count <= 4
    error_message = "availability_zone_count must be between 2 and 4 for high availability"
  }
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in VPC (only when vpc_create = true)"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support in VPC (only when vpc_create = true)"
  type        = bool
  default     = true
}

variable "create_private_subnets" {
  description = "Create private subnets with NAT gateway (only when vpc_create = true)"
  type        = bool
  default     = false
}

variable "enable_nat_gateway" {
  description = "Create NAT gateway for private subnet internet access (only when vpc_create = true and create_private_subnets = true)"
  type        = bool
  default     = false
}

variable "single_nat_gateway" {
  description = "Use single NAT gateway for cost optimization vs one per AZ (only when enable_nat_gateway = true)"
  type        = bool
  default     = false
}
