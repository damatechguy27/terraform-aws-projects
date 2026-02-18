# EKS IRSA Module

This module creates IAM Roles for Service Accounts (IRSA), allowing Kubernetes pods to assume IAM roles securely using OIDC authentication.

## Features

- IAM role with OIDC trust policy
- Automatic service account creation with role annotation
- Support for AWS managed and inline policies
- Least-privilege access with namespace and service account scoping
- Configurable session duration

## Usage

```hcl
module "irsa_aws_lb_controller" {
  source = "../../modules/eks-irsa"

  # Service account configuration
  service_account_name = "aws-load-balancer-controller"
  namespace            = "kube-system"

  # OIDC configuration
  cluster_name      = module.eks_cluster.cluster_name
  oidc_provider_arn = module.eks_cluster.cluster_oidc_provider_arn
  oidc_provider_url = replace(module.eks_cluster.cluster_oidc_issuer_url, "https://", "")

  # IAM role configuration
  role_name        = "eks-platform-est-dev-aws-lb-controller"
  role_description = "IAM role for AWS Load Balancer Controller"

  # Attach managed policies
  role_policy_arns = [
    aws_iam_policy.aws_lb_controller.arn
  ]

  tags = {
    Environment = "dev"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| service_account_name | Service account name | string | - | yes |
| namespace | Kubernetes namespace | string | "default" | no |
| cluster_name | EKS cluster name | string | - | yes |
| oidc_provider_arn | OIDC provider ARN | string | - | yes |
| oidc_provider_url | OIDC provider URL (no https://) | string | - | yes |
| role_name | IAM role name | string | - | yes |
| role_description | IAM role description | string | "" | no |
| role_policy_arns | Managed policy ARNs to attach | list(string) | [] | no |
| inline_policy_json | Inline policy JSON | string | "" | no |
| create_service_account | Create K8s service account | bool | true | no |
| max_session_duration | Max session duration (seconds) | number | 3600 | no |
| tags | Additional tags | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| iam_role_arn | IAM role ARN |
| iam_role_name | IAM role name |
| service_account_name | Service account name |
| service_account_namespace | Service account namespace |

## Resources Created

- `aws_iam_role` - IAM role with OIDC trust policy
- `aws_iam_role_policy_attachment` - Managed policy attachments
- `aws_iam_role_policy` - Inline policy (optional)
- `kubernetes_service_account_v1` - Kubernetes service account

## How IRSA Works

1. **OIDC Provider**: EKS cluster has an OIDC provider associated with it
2. **Trust Policy**: IAM role trusts the OIDC provider for specific namespace/SA
3. **Service Account**: Kubernetes SA is annotated with IAM role ARN
4. **Token Exchange**: Pod's service account token is exchanged for AWS credentials
5. **AWS API Access**: Pod can make AWS API calls using the IAM role

## OIDC Trust Policy

The module creates a trust policy that:

- Trusts the EKS cluster's OIDC provider (Federated principal)
- Restricts to specific namespace and service account (StringEquals condition)
- Validates the audience is `sts.amazonaws.com`

Example trust policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::ACCOUNT:oidc-provider/oidc.eks.REGION.amazonaws.com/id/XXXXX"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "oidc.eks.REGION.amazonaws.com/id/XXXXX:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller",
        "oidc.eks.REGION.amazonaws.com/id/XXXXX:aud": "sts.amazonaws.com"
      }
    }
  }]
}
```

## Example: S3 Access

```hcl
# Create IAM policy for S3 access
resource "aws_iam_policy" "s3_access" {
  name = "eks-app-s3-access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject"
      ]
      Resource = "arn:aws:s3:::my-bucket/*"
    }]
  })
}

# Create IRSA for app
module "irsa_app" {
  source = "../../modules/eks-irsa"

  service_account_name = "my-app"
  namespace            = "production"
  cluster_name         = module.eks_cluster.cluster_name
  oidc_provider_arn    = module.eks_cluster.cluster_oidc_provider_arn
  oidc_provider_url    = replace(module.eks_cluster.cluster_oidc_issuer_url, "https://", "")

  role_name        = "eks-app-s3-access"
  role_policy_arns = [aws_iam_policy.s3_access.arn]

  tags = { App = "my-app" }
}
```

## Example: Inline Policy

```hcl
module "irsa_custom" {
  source = "../../modules/eks-irsa"

  service_account_name = "custom-app"
  namespace            = "default"
  cluster_name         = module.eks_cluster.cluster_name
  oidc_provider_arn    = module.eks_cluster.cluster_oidc_provider_arn
  oidc_provider_url    = replace(module.eks_cluster.cluster_oidc_issuer_url, "https://", "")

  role_name = "eks-custom-app"

  # Use inline policy instead of managed policy
  inline_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:PutItem"
      ]
      Resource = "arn:aws:dynamodb:*:*:table/my-table"
    }]
  })

  inline_policy_name = "dynamodb-access"

  tags = { App = "custom-app" }
}
```

## Using IRSA in Pods

Deploy a pod that uses the service account:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: production
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      serviceAccountName: my-app  # References IRSA service account
      containers:
      - name: app
        image: my-app:latest
        # AWS SDK automatically uses IRSA credentials
        env:
        - name: AWS_REGION
          value: us-east-2
```

The pod will automatically have AWS credentials via environment variables:
- `AWS_ROLE_ARN` - IAM role ARN
- `AWS_WEB_IDENTITY_TOKEN_FILE` - Path to service account token

## Best Practices

1. **Least Privilege**: Grant minimum permissions needed
2. **Scope to Namespace**: Each namespace should have its own service accounts
3. **Separate Roles**: Don't share IAM roles across different applications
4. **Audit Regularly**: Review IAM policies and access patterns
5. **Session Duration**: Use default 1 hour unless longer sessions needed

## Security Considerations

- OIDC trust policy scopes to exact namespace and service account
- Audience validation prevents token reuse from other systems
- Service account tokens are automatically rotated by Kubernetes
- No long-lived AWS credentials stored in the cluster
- IAM policies can be updated without modifying pods

## Notes

- Service account creation is optional if it already exists
- OIDC provider URL must not include `https://` prefix
- Trust policy is automatically created with proper conditions
- Maximum session duration: 12 hours (43200 seconds)
- Recommended to use managed policies for reusability
