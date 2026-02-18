terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# AWS Provider with default tags
provider "aws" {
  region  = var.aws_region
  profile = "default-est-2"

  default_tags {
    tags = local.common_tags
  }
}

# Kubernetes provider configured after cluster creation
# Uses AWS CLI to get authentication token dynamically
provider "kubernetes" {
  host                   = try(module.eks_cluster.cluster_endpoint, "")
  cluster_ca_certificate = try(base64decode(module.eks_cluster.cluster_ca_cert), "")

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks", "get-token",
      "--cluster-name", try(module.eks_cluster.cluster_name, ""),
      "--region", var.aws_region,
      "--profile", "default-est-2"
    ]
  }

  # Skip validation during initial deployment when cluster doesn't exist
  ignore_annotations = [
    "^kubectl\\.kubernetes\\.io\\/.*"
  ]
}

# Helm provider configured using same authentication as Kubernetes
provider "helm" {
  kubernetes {
    host                   = try(module.eks_cluster.cluster_endpoint, "")
    cluster_ca_certificate = try(base64decode(module.eks_cluster.cluster_ca_cert), "")

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks", "get-token",
        "--cluster-name", try(module.eks_cluster.cluster_name, ""),
        "--region", var.aws_region,
        "--profile", "default-est-2"
      ]
    }
  }
}
