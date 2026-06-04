variable "name" {
  description = "ECS cluster name (used as the AWS identifier — renaming forces replacement)."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]{1,255}$", var.name))
    error_message = "Cluster name must match ^[a-zA-Z0-9_-]{1,255}$."
  }
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights. Small extra cost; recommended for prod."
  type        = bool
  default     = false
}

variable "default_capacity_provider" {
  description = "Default capacity provider used when a service doesn't specify one. Both FARGATE and FARGATE_SPOT are always available to services."
  type        = string
  default     = "FARGATE"

  validation {
    condition     = contains(["FARGATE", "FARGATE_SPOT"], var.default_capacity_provider)
    error_message = "default_capacity_provider must be FARGATE or FARGATE_SPOT."
  }
}

variable "tags" {
  description = "Additional tags applied to the cluster."
  type        = map(string)
  default     = {}
}
