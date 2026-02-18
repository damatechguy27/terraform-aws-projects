# ==============================================================================
# Terraform Backend Configuration
# ==============================================================================

# Local backend for testing and development
# For production, migrate to S3 backend with DynamoDB locking (see below)
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}

# ==============================================================================
# S3 Backend Configuration (RECOMMENDED FOR PRODUCTION)
# ==============================================================================
#
# Uncomment and configure the S3 backend for team collaboration and state locking
#
# Prerequisites:
# 1. Create S3 bucket:
#    aws s3api create-bucket \
#      --bucket YOUR-BUCKET-NAME \
#      --region us-east-2 \
#      --create-bucket-configuration LocationConstraint=us-east-2
#
# 2. Enable versioning:
#    aws s3api put-bucket-versioning \
#      --bucket YOUR-BUCKET-NAME \
#      --versioning-configuration Status=Enabled
#
# 3. Enable encryption:
#    aws s3api put-bucket-encryption \
#      --bucket YOUR-BUCKET-NAME \
#      --server-side-encryption-configuration \
#      '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
#
# 4. Create DynamoDB table for state locking:
#    aws dynamodb create-table \
#      --table-name terraform-state-locks \
#      --attribute-definitions AttributeName=LockID,AttributeType=S \
#      --key-schema AttributeName=LockID,KeyType=HASH \
#      --billing-mode PAY_PER_REQUEST \
#      --region us-east-2
#
# 5. Migrate from local to S3:
#    terraform init -migrate-state
#
# terraform {
#   backend "s3" {
#     bucket         = "YOUR-BUCKET-NAME"
#     key            = "simple-eks/dev/terraform.tfstate"
#     region         = "us-east-2"
#     encrypt        = true
#     dynamodb_table = "terraform-state-locks"
#   }
# }
