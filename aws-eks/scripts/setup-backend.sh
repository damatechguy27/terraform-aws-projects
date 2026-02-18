#!/bin/bash
# ==============================================================================
# Terraform Backend Setup Script
# ==============================================================================
# This script creates the S3 bucket and DynamoDB table required for
# Terraform remote state management.
#
# Usage:
#   ./scripts/setup-backend.sh [region]
#
# Example:
#   ./scripts/setup-backend.sh us-east-2
#   ./scripts/setup-backend.sh us-west-2
# ==============================================================================

set -e  # Exit on error
set -u  # Exit on undefined variable

# Configuration
PROJECT_NAME="eks-platform"
DEFAULT_REGION="us-east-2"

# Use provided region or default
AWS_REGION="${1:-$DEFAULT_REGION}"

# Derived names
S3_BUCKET="${PROJECT_NAME}-terraform-state"
DYNAMODB_TABLE="${PROJECT_NAME}-terraform-locks"

echo "========================================="
echo "Terraform Backend Setup"
echo "========================================="
echo "Project:        ${PROJECT_NAME}"
echo "Region:         ${AWS_REGION}"
echo "S3 Bucket:      ${S3_BUCKET}"
echo "DynamoDB Table: ${DYNAMODB_TABLE}"
echo "========================================="
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "ERROR: AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check AWS credentials
echo "Checking AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    echo "ERROR: AWS credentials not configured or invalid."
    echo "Please run 'aws configure' or set AWS environment variables."
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: ${ACCOUNT_ID}"
echo ""

# ==============================================================================
# Create S3 Bucket for Terraform State
# ==============================================================================

echo "Creating S3 bucket: ${S3_BUCKET}..."

# Check if bucket already exists
if aws s3api head-bucket --bucket "${S3_BUCKET}" --region "${AWS_REGION}" 2>/dev/null; then
    echo "  ✓ Bucket already exists: ${S3_BUCKET}"
else
    # Create bucket (with location constraint if not us-east-1)
    if [ "${AWS_REGION}" == "us-east-1" ]; then
        aws s3api create-bucket \
            --bucket "${S3_BUCKET}" \
            --region "${AWS_REGION}"
    else
        aws s3api create-bucket \
            --bucket "${S3_BUCKET}" \
            --region "${AWS_REGION}" \
            --create-bucket-configuration LocationConstraint="${AWS_REGION}"
    fi
    echo "  ✓ Created bucket: ${S3_BUCKET}"
fi

# Enable versioning
echo "Enabling versioning on S3 bucket..."
aws s3api put-bucket-versioning \
    --bucket "${S3_BUCKET}" \
    --versioning-configuration Status=Enabled
echo "  ✓ Versioning enabled"

# Enable encryption
echo "Enabling encryption on S3 bucket..."
aws s3api put-bucket-encryption \
    --bucket "${S3_BUCKET}" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }]
    }'
echo "  ✓ Encryption enabled (AES256)"

# Block public access
echo "Blocking public access to S3 bucket..."
aws s3api put-public-access-block \
    --bucket "${S3_BUCKET}" \
    --public-access-block-configuration \
        BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
echo "  ✓ Public access blocked"

# Add lifecycle policy to clean up old state versions (optional)
echo "Setting lifecycle policy for old versions..."
aws s3api put-bucket-lifecycle-configuration \
    --bucket "${S3_BUCKET}" \
    --lifecycle-configuration '{
        "Rules": [{
            "Id": "DeleteOldVersions",
            "Status": "Enabled",
            "NoncurrentVersionExpiration": {
                "NoncurrentDays": 90
            }
        }]
    }'
echo "  ✓ Lifecycle policy set (delete old versions after 90 days)"

# ==============================================================================
# Create DynamoDB Table for State Locking
# ==============================================================================

echo ""
echo "Creating DynamoDB table: ${DYNAMODB_TABLE}..."

# Check if table already exists
if aws dynamodb describe-table --table-name "${DYNAMODB_TABLE}" --region "${AWS_REGION}" &> /dev/null; then
    echo "  ✓ Table already exists: ${DYNAMODB_TABLE}"
else
    # Create table
    aws dynamodb create-table \
        --table-name "${DYNAMODB_TABLE}" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "${AWS_REGION}" \
        --tags Key=Project,Value="${PROJECT_NAME}" \
               Key=ManagedBy,Value=terraform \
               Key=Purpose,Value=state-locking

    echo "  ✓ Created table: ${DYNAMODB_TABLE}"
    echo "  ✓ Waiting for table to become active..."

    aws dynamodb wait table-exists \
        --table-name "${DYNAMODB_TABLE}" \
        --region "${AWS_REGION}"

    echo "  ✓ Table is active"
fi

# ==============================================================================
# Verify Default VPC Exists
# ==============================================================================

echo ""
echo "Verifying default VPC exists in ${AWS_REGION}..."

VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=isDefault,Values=true" \
    --region "${AWS_REGION}" \
    --query 'Vpcs[0].VpcId' \
    --output text 2>/dev/null || echo "None")

if [ "${VPC_ID}" == "None" ] || [ -z "${VPC_ID}" ]; then
    echo "  ⚠ WARNING: No default VPC found in ${AWS_REGION}"
    echo "  You may need to create a VPC or use a custom VPC configuration."
else
    echo "  ✓ Default VPC found: ${VPC_ID}"

    # Check subnets
    SUBNET_COUNT=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=${VPC_ID}" "Name=default-for-az,Values=true" \
        --region "${AWS_REGION}" \
        --query 'length(Subnets)' \
        --output text)

    echo "  ✓ Found ${SUBNET_COUNT} default subnets"

    if [ "${SUBNET_COUNT}" -lt 2 ]; then
        echo "  ⚠ WARNING: Less than 2 subnets found. EKS requires at least 2 AZs for HA."
    fi
fi

# ==============================================================================
# Summary
# ==============================================================================

echo ""
echo "========================================="
echo "Setup Complete!"
echo "========================================="
echo ""
echo "Backend Configuration:"
echo "  S3 Bucket:      ${S3_BUCKET}"
echo "  DynamoDB Table: ${DYNAMODB_TABLE}"
echo "  Region:         ${AWS_REGION}"
echo ""
echo "Next Steps:"
echo "  1. Review backend configuration in:"
echo "     branches/tech-branch-est/dev/backend.tf"
echo "  2. Initialize Terraform:"
echo "     cd branches/tech-branch-est/dev"
echo "     terraform init"
echo "  3. Plan and apply:"
echo "     terraform plan"
echo "     terraform apply"
echo ""
echo "========================================="
