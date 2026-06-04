# Read outputs from the infra stack (VPC, subnets, ECS cluster, ECR repo).
data "terraform_remote_state" "infra" {
  backend = "s3"

  config = {
    bucket = "damtechguy-tf-state-dev"
    key    = "client1/dev/infra/client1-infra-dev.tfstate"
    region = "us-west-2"
  }
}
