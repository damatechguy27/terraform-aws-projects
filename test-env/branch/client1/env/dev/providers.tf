terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# AWS Provider with default tags
provider "aws" {
  region  = local.region
  #profile = "default-est-2"

  default_tags {
    tags = local.common_tags
  }
}