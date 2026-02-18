# variables.tf
variable "region" {
  default = "us-east-2"
}

variable "cluster_name" {
  default = "my-eks-cluster"
}

variable "cluster_version" {
  default = "1.34"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

# vpc.tf
data "aws_availability_zones" "available" {
  state = "available"
}
