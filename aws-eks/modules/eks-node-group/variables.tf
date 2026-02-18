variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  validation {
    condition     = length(var.cluster_name) > 0
    error_message = "Cluster name cannot be empty"
  }
}

variable "node_group_name" {
  description = "Name for the node group"
  type        = string
  validation {
    condition     = length(var.node_group_name) > 0
    error_message = "Node group name cannot be empty"
  }
}

variable "node_role_arn" {
  description = "IAM role ARN for nodes"
  type        = string
  validation {
    condition     = can(regex("^arn:aws[a-z-]*:iam::", var.node_role_arn))
    error_message = "Node role ARN must be a valid IAM role ARN"
  }
}

variable "subnet_ids" {
  description = "Subnet IDs for node placement (must be in at least 2 AZs for HA)"
  type        = list(string)
  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "At least 2 subnets required for high availability"
  }
}

variable "node_security_group_id" {
  description = "Security group ID for nodes"
  type        = string
  validation {
    condition     = can(regex("^sg-", var.node_security_group_id))
    error_message = "Security group ID must start with 'sg-'"
  }
}

variable "instance_types" {
  description = "List of instance types for node group"
  type        = list(string)
  default     = ["t3.medium"]
  validation {
    condition     = length(var.instance_types) > 0
    error_message = "At least one instance type must be specified"
  }
}

variable "capacity_type" {
  description = "Capacity type: ON_DEMAND or SPOT"
  type        = string
  default     = "ON_DEMAND"
  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.capacity_type)
    error_message = "Capacity type must be ON_DEMAND or SPOT"
  }
}

variable "ami_type" {
  description = "Type of AMI to use for nodes"
  type        = string
  default     = "AL2023_x86_64_STANDARD"
  validation {
    condition = contains([
      "AL2_x86_64",
      "AL2_x86_64_GPU",
      "AL2_ARM_64",
      "AL2023_x86_64_STANDARD",
      "AL2023_ARM_64_STANDARD",
      "BOTTLEROCKET_ARM_64",
      "BOTTLEROCKET_x86_64",
      "BOTTLEROCKET_ARM_64_NVIDIA",
      "BOTTLEROCKET_x86_64_NVIDIA"
    ], var.ami_type)
    error_message = "Invalid AMI type specified"
  }
}

variable "disk_size" {
  description = "Disk size in GB for nodes"
  type        = number
  default     = 20
  validation {
    condition     = var.disk_size >= 20 && var.disk_size <= 1000
    error_message = "Disk size must be between 20 and 1000 GB"
  }
}

variable "disk_type" {
  description = "Disk type for nodes (gp3, gp2, io1, io2)"
  type        = string
  default     = "gp3"
  validation {
    condition     = contains(["gp3", "gp2", "io1", "io2"], var.disk_type)
    error_message = "Disk type must be gp3, gp2, io1, or io2"
  }
}

variable "desired_size" {
  description = "Desired number of nodes"
  type        = number
  default     = 2
  validation {
    condition     = var.desired_size >= 1
    error_message = "Desired size must be at least 1"
  }
}

variable "min_size" {
  description = "Minimum number of nodes"
  type        = number
  default     = 2
  validation {
    condition     = var.min_size >= 1
    error_message = "Minimum size must be at least 1"
  }
}

variable "max_size" {
  description = "Maximum number of nodes"
  type        = number
  default     = 4
  validation {
    condition     = var.max_size >= 1
    error_message = "Maximum size must be at least 1"
  }
}

variable "max_unavailable" {
  description = "Maximum number of nodes unavailable during update"
  type        = number
  default     = 1
  validation {
    condition     = var.max_unavailable >= 1
    error_message = "Max unavailable must be at least 1"
  }
}

variable "labels" {
  description = "Kubernetes labels to apply to nodes"
  type        = map(string)
  default     = {}
}

variable "taints" {
  description = "Kubernetes taints to apply to nodes"
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = []
  validation {
    condition = alltrue([
      for taint in var.taints :
      contains(["NoSchedule", "NoExecute", "PreferNoSchedule"], taint.effect)
    ])
    error_message = "Taint effect must be NoSchedule, NoExecute, or PreferNoSchedule"
  }
}

variable "enable_monitoring" {
  description = "Enable CloudWatch detailed monitoring"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
