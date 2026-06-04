variable "name" {
  description = "Name of the ECR repository (e.g. 'client1-infra-dev-api'). Lowercase, may contain hyphens, slashes, underscores."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9._/-]{1,255}$", var.name))
    error_message = "ECR repo name must be lowercase and start with a letter or number."
  }
}

variable "image_tag_mutability" {
  description = "Whether image tags can be overwritten. IMMUTABLE strongly recommended for prod (prevents tag hijacking)."
  type        = string
  default     = "IMMUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be MUTABLE or IMMUTABLE."
  }
}

variable "scan_on_push" {
  description = "Enable AWS-native vulnerability scanning on every push."
  type        = bool
  default     = true
}

variable "encryption_type" {
  description = "Encryption type for images at rest: AES256 (default, free) or KMS (CMK-managed, paid)."
  type        = string
  default     = "AES256"

  validation {
    condition     = contains(["AES256", "KMS"], var.encryption_type)
    error_message = "encryption_type must be AES256 or KMS."
  }
}

variable "kms_key_arn" {
  description = "KMS key ARN, required when encryption_type = KMS. If null with KMS, AWS-managed aws/ecr key is used."
  type        = string
  default     = null
}

variable "force_delete" {
  description = "Allow Terraform to destroy the repo even if it contains images. DANGEROUS in prod."
  type        = bool
  default     = false
}

variable "lifecycle_keep_last_n_tagged" {
  description = "Keep the most recent N tagged images; older ones are expired. Set to 0 to disable this rule."
  type        = number
  default     = 30
}

variable "lifecycle_untagged_expire_days" {
  description = "Expire untagged images after this many days. Set to 0 to disable this rule."
  type        = number
  default     = 14
}

variable "tags" {
  description = "Additional tags applied to the repository."
  type        = map(string)
  default     = {}
}
