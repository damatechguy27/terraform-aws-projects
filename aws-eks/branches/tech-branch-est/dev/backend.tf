# Temporarily using local backend for testing
# Uncomment S3 backend below when credentials are working
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}

# terraform {
#   backend "s3" {
#     bucket = "damtechguy-eks-platform-ft-state"
#     key    = "eks/tech-branch-est/dev/terraform.tfstate"
#     region = "us-east-2"
#     # dynamodb_table = "eks-platform-terraform-locks"
#     encrypt = true
#   }
# }
