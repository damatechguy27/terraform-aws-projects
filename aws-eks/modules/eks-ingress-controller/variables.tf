variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  validation {
    condition     = length(var.cluster_name) > 0
    error_message = "Cluster name cannot be empty"
  }
}

variable "vpc_id" {
  description = "VPC ID for the AWS Load Balancer Controller"
  type        = string
  validation {
    condition     = can(regex("^vpc-", var.vpc_id))
    error_message = "VPC ID must start with 'vpc-'"
  }
}

variable "service_account_role_arn" {
  description = "ARN of the IAM role for the AWS Load Balancer Controller service account"
  type        = string
  validation {
    condition     = can(regex("^arn:aws[a-z-]*:iam::", var.service_account_role_arn))
    error_message = "Service account role ARN must be a valid IAM role ARN"
  }
}

variable "chart_version" {
  description = "Version of the AWS Load Balancer Controller Helm chart"
  type        = string
  default     = "1.7.1"
}

variable "chart_repository" {
  description = "Helm chart repository URL"
  type        = string
  default     = "https://aws.github.io/eks-charts"
}

variable "chart_name" {
  description = "Name of the Helm chart"
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "release_name" {
  description = "Name for the Helm release"
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "namespace" {
  description = "Kubernetes namespace for the AWS Load Balancer Controller"
  type        = string
  default     = "kube-system"
}

variable "create_namespace" {
  description = "Create namespace if it doesn't exist"
  type        = bool
  default     = false
}

variable "service_account_name" {
  description = "Name of the service account (must match IRSA module)"
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "replica_count" {
  description = "Number of replicas for the controller"
  type        = number
  default     = 2
  validation {
    condition     = var.replica_count >= 1 && var.replica_count <= 10
    error_message = "Replica count must be between 1 and 10"
  }
}

variable "enable_shield" {
  description = "Enable AWS Shield for ALBs"
  type        = bool
  default     = false
}

variable "enable_waf" {
  description = "Enable AWS WAF for ALBs"
  type        = bool
  default     = false
}

variable "enable_wafv2" {
  description = "Enable AWS WAFv2 for ALBs"
  type        = bool
  default     = false
}

variable "log_level" {
  description = "Log level for the controller (debug, info, warn, error)"
  type        = string
  default     = "info"
  validation {
    condition     = contains(["debug", "info", "warn", "error"], var.log_level)
    error_message = "Log level must be one of: debug, info, warn, error"
  }
}

variable "helm_values_overrides" {
  description = "Additional Helm values to override (YAML string)"
  type        = string
  default     = ""
}

variable "wait_for_deployment" {
  description = "Wait for deployment to complete"
  type        = bool
  default     = true
}

variable "timeout" {
  description = "Timeout for Helm operations in seconds"
  type        = number
  default     = 600
}
