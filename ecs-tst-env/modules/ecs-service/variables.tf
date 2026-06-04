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
  description = "Number of tasks the service keeps running."
  type        = number
  default     = 2

  validation {
    condition     = var.desired_count >= 1
    error_message = "desired_count must be >= 1. For HA in prod, use >= 2."
  }
}

variable "ingress_cidrs" {
  description = "CIDR blocks allowed to reach the container_port. Empty list = no ingress (e.g. when fronted by an ALB whose SG you add via additional_security_group_ids)."
  type        = list(string)
  default     = []
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
