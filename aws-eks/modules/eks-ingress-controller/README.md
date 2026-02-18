# EKS Ingress Controller Module

This module deploys the AWS Load Balancer Controller via Helm, enabling native AWS ALB and NLB integration for Kubernetes Ingress resources.

## Features

- Automated Helm chart deployment
- Native AWS ALB and NLB provisioning
- IRSA integration for secure AWS API access
- High availability with multiple replicas
- Support for AWS WAF and Shield integration
- Configurable logging and resource limits

## Usage

```hcl
module "ingress_controller" {
  source = "../../modules/eks-ingress-controller"

  # Cluster configuration
  cluster_name = module.eks_cluster.cluster_name
  vpc_id       = data.aws_vpc.selected.id

  # IRSA configuration
  service_account_role_arn = module.irsa_aws_lb_controller.iam_role_arn
  service_account_name     = "aws-load-balancer-controller"

  # Helm chart configuration
  chart_version = "1.7.1"
  namespace     = "kube-system"

  # Deployment configuration
  replica_count = 2
  log_level     = "info"

  # Ensure nodes are ready before deploying
  depends_on = [module.eks_node_group_system]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| cluster_name | EKS cluster name | string | - | yes |
| vpc_id | VPC ID | string | - | yes |
| service_account_role_arn | IAM role ARN for SA | string | - | yes |
| service_account_name | Service account name | string | "aws-load-balancer-controller" | no |
| chart_version | Helm chart version | string | "1.7.1" | no |
| namespace | Kubernetes namespace | string | "kube-system" | no |
| replica_count | Number of replicas | number | 2 | no |
| log_level | Log level (debug/info/warn/error) | string | "info" | no |
| enable_shield | Enable AWS Shield | bool | false | no |
| enable_waf | Enable AWS WAF v1 | bool | false | no |
| enable_wafv2 | Enable AWS WAFv2 | bool | false | no |
| wait_for_deployment | Wait for deployment | bool | true | no |
| timeout | Helm timeout (seconds) | number | 600 | no |

## Outputs

| Name | Description |
|------|-------------|
| release_name | Helm release name |
| release_namespace | Helm release namespace |
| release_status | Helm release status |
| release_version | Helm chart version |

## Resources Created

- `helm_release.aws_lb_controller` - Helm release for AWS Load Balancer Controller

## AWS Load Balancer Controller

The AWS Load Balancer Controller is a Kubernetes controller that:

1. **Provisions ALB/NLB**: Automatically creates AWS load balancers for Ingress resources
2. **Target Registration**: Registers pods as targets in load balancer target groups
3. **Health Checks**: Configures health checks based on pod readiness
4. **WAF Integration**: Supports AWS WAF for application protection
5. **Certificate Management**: Integrates with ACM for TLS certificates

## Prerequisites

Before deploying this module, ensure:

1. **IRSA Role Created**: IAM role with AWS Load Balancer Controller policy
2. **Nodes Running**: At least one node available in the cluster
3. **VPC Tags**: Subnets should be tagged for automatic discovery (optional)

### Subnet Tagging (Optional)

For automatic subnet discovery, tag subnets:

```
# Public subnets (for internet-facing ALBs)
kubernetes.io/role/elb = 1

# Private subnets (for internal ALBs)
kubernetes.io/role/internal-elb = 1
```

## Example: Creating an ALB Ingress

After deploying the controller, create an Ingress resource:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress
  namespace: default
  annotations:
    # Ingress class
    kubernetes.io/ingress.class: alb

    # ALB scheme (internet-facing or internal)
    alb.ingress.kubernetes.io/scheme: internet-facing

    # Target type (ip or instance)
    alb.ingress.kubernetes.io/target-type: ip

    # Health check configuration
    alb.ingress.kubernetes.io/healthcheck-path: /health
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: '30'
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: '5'
    alb.ingress.kubernetes.io/healthy-threshold-count: '2'
    alb.ingress.kubernetes.io/unhealthy-threshold-count: '2'

    # SSL/TLS
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:region:account:certificate/xxx

    # Security
    alb.ingress.kubernetes.io/security-groups: sg-xxx

spec:
  rules:
  - host: example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-app
            port:
              number: 80
```

## Example: NLB Service

Create a Service with NLB:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app-nlb
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: external
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
spec:
  type: LoadBalancer
  selector:
    app: my-app
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
```

## High Availability

The module deploys the controller with HA in mind:

- **Multiple Replicas**: Default 2 replicas for redundancy
- **Pod Disruption Budget**: Ensures at least 1 replica during updates
- **Resource Limits**: Prevents resource exhaustion
- **Anti-Affinity**: (Optional) Spreads replicas across nodes

## Resource Configuration

Default resource allocation:

```yaml
resources:
  limits:
    cpu: 200m
    memory: 500Mi
  requests:
    cpu: 100m
    memory: 200Mi
```

Adjust based on cluster size and load balancer count.

## Monitoring

Check controller status:

```bash
# Check pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check Helm release
helm list -n kube-system
```

## Troubleshooting

### Issue: Controller pods not starting

**Check**:
```bash
kubectl describe pod -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

**Common causes**:
- IAM role ARN incorrect or missing permissions
- Service account not properly annotated
- Insufficient resources on nodes

### Issue: ALB not being created

**Check controller logs**:
```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=100
```

**Common causes**:
- Ingress class not set to `alb`
- Subnet tags missing (if not explicitly specifying subnets)
- IAM permissions insufficient
- VPC ID mismatch

### Issue: Health checks failing

**Check target group**:
```bash
aws elbv2 describe-target-health --target-group-arn <tg-arn>
```

**Common causes**:
- Health check path incorrect
- Pods not ready
- Security group blocking health check traffic

## IAM Policy Requirements

The controller requires extensive IAM permissions. Use the official policy:

```bash
curl -o iam-policy.json \
  https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
```

Key permissions:
- EC2: Describe, create security groups, manage network interfaces
- ELB: Create/delete/modify load balancers and target groups
- IAM: Create service-linked roles
- ACM: Describe certificates
- WAF/Shield: Associate web ACLs (if enabled)

## Annotations Reference

### Common Ingress Annotations

| Annotation | Description | Example |
|------------|-------------|---------|
| `alb.ingress.kubernetes.io/scheme` | Internet-facing or internal | `internet-facing` |
| `alb.ingress.kubernetes.io/target-type` | Target type | `ip` or `instance` |
| `alb.ingress.kubernetes.io/certificate-arn` | ACM certificate ARN | `arn:aws:acm:...` |
| `alb.ingress.kubernetes.io/listen-ports` | Listener ports | `[{"HTTP": 80}, {"HTTPS": 443}]` |
| `alb.ingress.kubernetes.io/ssl-policy` | SSL policy | `ELBSecurityPolicy-TLS-1-2-2017-01` |
| `alb.ingress.kubernetes.io/wafv2-acl-arn` | WAFv2 ACL ARN | `arn:aws:wafv2:...` |

Full reference: https://kubernetes-sigs.github.io/aws-load-balancer-controller/

## Upgrade

To upgrade the controller:

```bash
# Update chart version in Terraform
# vim main.tf
# chart_version = "1.8.0"

terraform plan
terraform apply
```

The module uses `wait_for_deployment = true` by default, ensuring the upgrade completes successfully.

## Notes

- Deployment takes approximately 2-3 minutes
- Controller watches for Ingress and Service resources cluster-wide
- Load balancers are automatically deleted when Ingress resources are removed
- ALB name includes cluster name and namespace for identification
- Supports both IPv4 and IPv6 (dualstack mode)
