variable "container_image_tag" {
  description = "ECR image tag deployed on the api service. Set by services/deploy.sh on each release; bootstrap value lets the first apply succeed before any image has been pushed."
  type        = string
  default     = "bootstrap"
}
