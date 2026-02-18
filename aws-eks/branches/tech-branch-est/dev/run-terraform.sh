#!/bin/bash
# Script to run Terraform with proper AWS credentials

# Export AWS credentials from SSO
echo "Exporting AWS credentials..."
eval $(aws configure export-credentials --profile default-est-2 --format env)

# Verify credentials are set
if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    echo "Error: Failed to export AWS credentials"
    echo "Run: aws sso login --profile default-est-2"
    exit 1
fi

echo "✓ AWS credentials exported"
echo "  Access Key: ${AWS_ACCESS_KEY_ID:0:20}..."
echo "  Region: us-east-2"
echo ""

# Run terraform with the provided command
echo "Running: terraform $@"
terraform "$@"
