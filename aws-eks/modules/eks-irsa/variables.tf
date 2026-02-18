variable "service_account_name" {
  description = "Name of the Kubernetes service account"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.service_account_name))
    error_message = "Service account name must be a valid Kubernetes name"
  }
}

variable "namespace" {
  description = "Kubernetes namespace for the service account"
  type        = string
  default     = "default"
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.namespace))
    error_message = "Namespace must be a valid Kubernetes namespace name"
  }
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  validation {
    condition     = length(var.cluster_name) > 0
    error_message = "Cluster name cannot be empty"
  }
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider for the EKS cluster"
  type        = string
  validation {
    condition     = can(regex("^arn:aws[a-z-]*:iam::", var.oidc_provider_arn))
    error_message = "OIDC provider ARN must be a valid ARN"
  }
}

variable "oidc_provider_url" {
  description = "URL of the OIDC provider (without https:// prefix)"
  type        = string
  validation {
    condition     = !can(regex("^https://", var.oidc_provider_url))
    error_message = "OIDC provider URL must not include https:// prefix"
  }
}

variable "role_name" {
  description = "Name for the IAM role"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9+=,.@_-]+$", var.role_name))
    error_message = "Role name contains invalid characters"
  }
}

variable "role_description" {
  description = "Description for the IAM role"
  type        = string
  default     = ""
}

variable "role_policy_arns" {
  description = "List of IAM policy ARNs to attach to the role"
  type        = list(string)
  default     = []
}

variable "inline_policy_json" {
  description = "Inline IAM policy JSON document (optional)"
  type        = string
  default     = ""
}

variable "inline_policy_name" {
  description = "Name for inline policy (required if inline_policy_json is provided)"
  type        = string
  default     = "inline-policy"
}

variable "max_session_duration" {
  description = "Maximum session duration in seconds for the IAM role"
  type        = number
  default     = 3600
  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "Max session duration must be between 3600 (1 hour) and 43200 (12 hours)"
  }
}

variable "create_service_account" {
  description = "Whether to create the Kubernetes service account (set false if it already exists)"
  type        = bool
  default     = true
}

variable "service_account_annotations" {
  description = "Additional annotations for the service account"
  type        = map(string)
  default     = {}
}

variable "service_account_labels" {
  description = "Additional labels for the service account"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Additional tags to apply to IAM resources"
  type        = map(string)
  default     = {}
}
