# Read outputs from the infra stack (VPC, subnets, ECS cluster, ECR repo).
data "terraform_remote_state" "infra" {
  backend = "s3"

  config = {
    bucket = "damtechguy-tf-state-dev"
    key    = "client1/dev/infra/client1-infra-dev.tfstate"
    region = "us-west-2"
  }
}

# Resolve each service's image tag to the most recently pushed image in the shared
# repo whose tag starts with the service's image_prefix. Requires aws + jq on PATH.
# NOTE: this makes the deployed image depend on ECR state at plan time, so a plain
# `apply` rolls services to whatever the newest matching image is (not pinned).
data "external" "latest_image" {
  for_each = local.services

  program = ["bash", "${path.module}/../../../services/latest-ecr-tag.sh"]

  query = {
    repository_name = local.api_repo_name
    region          = local.region
    prefix          = each.value.image_prefix
  }
}
