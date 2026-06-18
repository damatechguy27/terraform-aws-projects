variable "name_prefix" {
  description = "Prefix for service, task family, SG, log group, and IAM role names (e.g. 'client1-infra-dev-api')."
  type        = string
}

variable "cluster_id" {
  description = "ECS cluster ID (ARN) the service is deployed onto. Use module.ecs_cluster.cluster_id — that output depends on the cluster's capacity providers being registered."
  type        = string
}

variable "vpc_id" {
  description = "VPC the service runs in. Used for the service security group."
  type        = string
}

variable "subnet_ids" {
  description = "Subnets the service tasks are placed in. Use private subnets with a NAT for prod; public subnets with assign_public_ip=true for cheap dev."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "Provide at least 2 subnet IDs across distinct AZs for HA."
  }
}

variable "assign_public_ip" {
  description = "Assign a public IP to each task. Required if subnets are public and you have no NAT (so tasks can pull from ECR)."
  type        = bool
  default     = false
}

variable "container_image" {
  description = "Full image reference, e.g. '<account>.dkr.ecr.<region>.amazonaws.com/myrepo:v1'."
  type        = string
}

variable "container_port" {
  description = "Port the container listens on. Exposed via the service security group."
  type        = number
  default     = 80
}

variable "container_environment" {
  description = "Non-sensitive environment variables injected into the container."
  type        = list(object({ name = string, value = string }))
  default     = []
}

variable "container_secrets" {
  description = "Secrets pulled at runtime from SSM Parameter Store or Secrets Manager. valueFrom is the parameter/secret ARN."
  type        = list(object({ name = string, valueFrom = string }))
  default     = []
}

variable "task_cpu" {
  description = "Fargate task CPU units. Valid Fargate combos: 256/512/1024/2048/4096/8192/16384."
  type        = number
  default     = 256

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096, 8192, 16384], var.task_cpu)
    error_message = "task_cpu must be a valid Fargate value."
  }
}

variable "task_memory" {
  description = "Fargate task memory in MiB. Must be a valid combo with task_cpu (see AWS docs)."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Initial number of tasks the service runs. When autoscaling is enabled (min_count + max_count set), this is only the starting count — the service ignores later drift so the autoscaler owns it."
  type        = number
  default     = 2

  validation {
    condition     = var.desired_count >= 1
    error_message = "desired_count must be >= 1. For HA in prod, use >= 2."
  }
}

variable "min_count" {
  description = "Minimum task count for Application Auto Scaling. Set together with max_count to enable autoscaling; leave both null to disable."
  type        = number
  default     = null
}

variable "max_count" {
  description = "Maximum task count for Application Auto Scaling. Set together with min_count to enable autoscaling; leave both null to disable."
  type        = number
  default     = null
}

# --- Step scaling: scale OUT (CPU high) ------------------------------------------------
# nullable = false on these: the platform stack passes try(each.value.X, null), so apps that
# omit a field send null and Terraform substitutes the default below.
variable "autoscaling_high_threshold" {
  description = "CPU utilization (%) above which the service scales out. Only used when autoscaling is enabled."
  type        = number
  default     = 70
  nullable    = false

  validation {
    condition     = var.autoscaling_high_threshold > 0 && var.autoscaling_high_threshold <= 100
    error_message = "autoscaling_high_threshold must be in (0, 100]."
  }
}

variable "autoscaling_high_period" {
  description = "Seconds per datapoint for the scale-out alarm. Must be 10, 30, or a multiple of 60."
  type        = number
  default     = 60
  nullable    = false
}

variable "autoscaling_high_evaluation_periods" {
  description = "Number of most-recent datapoints the scale-out alarm evaluates (the M in 'N of M')."
  type        = number
  default     = 5
  nullable    = false
}

variable "autoscaling_high_datapoints_to_alarm" {
  description = "Number of breaching datapoints within the evaluation window that trip scale-out (the N in 'N of M'). Default: 3 of 5 one-minute datapoints = high for ~3 of the last 5 minutes."
  type        = number
  default     = 3
  nullable    = false
}

variable "autoscaling_scale_out_adjustment" {
  description = "Number of tasks to ADD on each scale-out step."
  type        = number
  default     = 1
  nullable    = false
}

variable "autoscaling_scale_out_cooldown" {
  description = "Seconds to wait after a scale-out before another scale-out."
  type        = number
  default     = 60
  nullable    = false
}

# --- Step scaling: scale IN (CPU low) --------------------------------------------------
variable "autoscaling_low_threshold" {
  description = "CPU utilization (%) below which the service scales in. Only used when autoscaling is enabled."
  type        = number
  default     = 70
  nullable    = false

  validation {
    condition     = var.autoscaling_low_threshold > 0 && var.autoscaling_low_threshold <= 100
    error_message = "autoscaling_low_threshold must be in (0, 100]."
  }
}

variable "autoscaling_low_period" {
  description = "Seconds per datapoint for the scale-in alarm. Must be 10, 30, or a multiple of 60."
  type        = number
  default     = 60
  nullable    = false
}

variable "autoscaling_low_evaluation_periods" {
  description = "Number of most-recent datapoints the scale-in alarm evaluates. Default: 10 one-minute datapoints = low for 10 minutes."
  type        = number
  default     = 10
  nullable    = false
}

variable "autoscaling_low_datapoints_to_alarm" {
  description = "Number of low datapoints within the evaluation window that trip scale-in. Default 10 (all 10 minutes below threshold)."
  type        = number
  default     = 10
  nullable    = false
}

variable "autoscaling_scale_in_adjustment" {
  description = "Number of tasks to REMOVE on each scale-in step (positive number; applied as a decrease)."
  type        = number
  default     = 1
  nullable    = false

  validation {
    condition     = var.autoscaling_scale_in_adjustment > 0
    error_message = "autoscaling_scale_in_adjustment is the count to remove; use a positive number."
  }
}

variable "autoscaling_scale_in_cooldown" {
  description = "Seconds to wait after a scale-in before another scale-in."
  type        = number
  default     = 300
  nullable    = false
}

variable "ingress_rules" {
  description = "Ingress rules for the service security group. Each rule opens a port range to a CIDR. Empty list = no ingress (e.g. when fronted by an ALB whose SG you add via additional_security_group_ids)."
  type = list(object({
    cidr        = string
    from_port   = number
    to_port     = number
    protocol    = optional(string, "tcp")
    description = optional(string)
  }))
  default = []

  validation {
    condition     = alltrue([for r in var.ingress_rules : can(cidrhost(r.cidr, 0))])
    error_message = "Each ingress rule cidr must be a valid IPv4 CIDR (e.g. 10.0.0.0/8 or 0.0.0.0/0)."
  }

  validation {
    condition     = alltrue([for r in var.ingress_rules : r.from_port <= r.to_port])
    error_message = "Each ingress rule must have from_port <= to_port."
  }
}

variable "additional_security_group_ids" {
  description = "Extra SGs to attach to the service (e.g. an ALB target SG that allows the ALB to reach tasks)."
  type        = list(string)
  default     = []
}

variable "task_role_arn" {
  description = "IAM role the running container assumes (for app-level AWS API calls). If null, an empty role is created."
  type        = string
  default     = null
}

variable "log_retention_days" {
  description = "CloudWatch log retention. Never set to 0 (= unlimited)."
  type        = number
  default     = 14

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a valid CloudWatch retention value (no unlimited)."
  }
}

variable "enable_execute_command" {
  description = "Enable ECS Exec (kubectl-exec-style shell into tasks). Adds SSM perms to the task role."
  type        = bool
  default     = false
}

variable "use_fargate_spot" {
  description = "Run tasks on Fargate Spot (~70% cheaper). Suitable for interruption-tolerant workloads. Requires the cluster to have FARGATE_SPOT in its capacity providers."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags applied to every resource in this module."
  type        = map(string)
  default     = {}
}
