# AWS EKS Infrastructure Guide

## Overview

This project provides a production-ready, modular Terraform infrastructure for deploying Amazon EKS (Elastic Kubernetes Service) clusters with managed node groups, VPC networking, IRSA (IAM Roles for Service Accounts), and the AWS Load Balancer Controller.

**Key Features:**
- ✅ Modular, reusable Terraform architecture
- ✅ Optional VPC creation or use existing VPC
- ✅ EKS cluster with managed node groups
- ✅ IRSA (IAM Roles for Service Accounts) with OIDC provider
- ✅ AWS Load Balancer Controller for Ingress
- ✅ Encrypted EBS volumes with IMDSv2 enforcement
- ✅ Multi-AZ high availability
- ✅ Production-ready security configurations

---

## Architecture Overview

```mermaid
graph TB
    subgraph "AWS Cloud"
        subgraph "VPC 10.0.0.0/16"
            subgraph "AZ1 - us-east-2a"
                PubSub1[Public Subnet<br/>10.0.100.0/24]
                Node1[EKS Node 1<br/>t3.medium]
            end

            subgraph "AZ2 - us-east-2b"
                PubSub2[Public Subnet<br/>10.0.101.0/24]
                Node2[EKS Node 2<br/>t3.medium]
            end

            IGW[Internet Gateway]

            subgraph "EKS Control Plane - Managed by AWS"
                EKS[EKS Cluster<br/>v1.34]
                OIDC[OIDC Provider<br/>for IRSA]
            end
        end

        subgraph "IAM"
            ClusterRole[Cluster IAM Role<br/>+2 policies]
            NodeRole[Node IAM Role<br/>+6 policies]
            LBRole[LB Controller<br/>IAM Role]
        end

        subgraph "Kubernetes Workloads"
            AWSLB[AWS LB Controller<br/>2 replicas]
            App[Your Applications<br/>with Ingress]
        end

        ALB[Application Load<br/>Balancer]
        CW[CloudWatch Logs]
    end

    Internet([Internet]) --> IGW
    IGW --> PubSub1
    IGW --> PubSub2

    PubSub1 --> Node1
    PubSub2 --> Node2

    Node1 --> EKS
    Node2 --> EKS

    EKS --> ClusterRole
    Node1 --> NodeRole
    Node2 --> NodeRole

    EKS --> CW
    EKS --> OIDC
    OIDC --> LBRole

    AWSLB --> LBRole
    AWSLB --> ALB
    App --> AWSLB

    ALB --> Internet

    style EKS fill:#FF9900
    style Node1 fill:#3F8624
    style Node2 fill:#3F8624
    style AWSLB fill:#326CE5
    style App fill:#326CE5
```

---

## Module Structure

The infrastructure is organized into **4 reusable modules** that work together:

```mermaid
graph LR
    subgraph "Modules"
        EKSCluster[eks-cluster<br/>Core EKS + VPC]
        NodeGroup[eks-node-group<br/>Managed Nodes]
        IRSA[eks-irsa<br/>Service Accounts]
        Ingress[eks-ingress-controller<br/>AWS LB Controller]
    end

    subgraph "Environment: dev"
        Main[main.tf<br/>Orchestrates modules]
    end

    Main --> EKSCluster
    Main --> NodeGroup
    Main --> IRSA
    Main --> Ingress

    EKSCluster -.provides.-> NodeGroup
    EKSCluster -.provides.-> IRSA
    EKSCluster -.provides.-> Ingress
    IRSA -.provides.-> Ingress

    style EKSCluster fill:#FF9900
    style NodeGroup fill:#3F8624
    style IRSA fill:#FF6B6B
    style Ingress fill:#4ECDC4
```

### Module Responsibilities

| Module | Purpose | Key Resources |
|--------|---------|---------------|
| **eks-cluster** | Core EKS cluster, networking, IAM, security groups | VPC, Subnets, IGW, EKS Cluster, OIDC Provider, IAM Roles, Security Groups |
| **eks-node-group** | Managed worker nodes with launch template | Launch Template, EKS Node Group, Auto Scaling |
| **eks-irsa** | IAM Roles for Service Accounts integration | Kubernetes Service Account, IAM Role with Trust Policy |
| **eks-ingress-controller** | AWS Load Balancer Controller via Helm | Helm Release, Controller Deployment |

---

## Directory Structure

```
aws-eks/
├── modules/                          # Reusable Terraform modules
│   ├── eks-cluster/                  # Core EKS cluster module
│   │   ├── main.tf                   # EKS cluster, OIDC provider, access entry
│   │   ├── networking.tf             # VPC, subnets, IGW, NAT, route tables
│   │   ├── security_groups.tf        # Cluster and node security groups
│   │   ├── iam.tf                    # IAM roles and policies
│   │   ├── variables.tf              # Input variables
│   │   ├── outputs.tf                # Module outputs
│   │   ├── locals.tf                 # Local values
│   │   └── data.tf                   # Data sources
│   │
│   ├── eks-node-group/               # Managed node group module
│   │   ├── main.tf                   # Launch template + node group
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── locals.tf
│   │
│   ├── eks-irsa/                     # IRSA module
│   │   ├── main.tf                   # Service account + IAM role
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── locals.tf
│   │
│   └── eks-ingress-controller/       # AWS LB Controller module
│       ├── main.tf                   # Helm release
│       ├── variables.tf
│       └── outputs.tf
│
├── branches/                         # Environment-specific configurations
│   └── tech-branch-est/
│       └── dev/                      # Development environment
│           ├── main.tf               # Module orchestration
│           ├── variables.tf          # Environment variables
│           ├── outputs.tf            # Environment outputs
│           ├── data.tf               # Data sources
│           ├── locals.tf             # Local values
│           ├── provider.tf           # AWS provider config
│           ├── backend.tf            # State backend (local/S3)
│           ├── terraform.tfvars      # Variable values
│           └── aws-lb-controller-iam-policy.json  # IAM policy
│
└── README.md                         # Quick start guide
```

---

## Deployment Flow

```mermaid
sequenceDiagram
    participant User
    participant Terraform
    participant AWS
    participant EKS
    participant Kubernetes

    User->>Terraform: terraform apply

    Note over Terraform: Phase 1: Networking
    Terraform->>AWS: Create VPC (10.0.0.0/16)
    Terraform->>AWS: Create 2 Public Subnets (multi-AZ)
    Terraform->>AWS: Create Internet Gateway
    Terraform->>AWS: Create Route Tables

    Note over Terraform: Phase 2: IAM
    Terraform->>AWS: Create Cluster IAM Role
    Terraform->>AWS: Attach 2 Cluster Policies
    Terraform->>AWS: Create Node IAM Role
    Terraform->>AWS: Attach 6 Node Policies

    Note over Terraform: Phase 3: Security Groups
    Terraform->>AWS: Create Cluster Security Group
    Terraform->>AWS: Create Node Security Group
    Terraform->>AWS: Configure SG Rules (443, 10250, ephemeral)

    Note over Terraform: Phase 4: EKS Cluster
    Terraform->>EKS: Create EKS Cluster v1.34
    EKS-->>AWS: Create CloudWatch Log Group
    EKS-->>AWS: Provision Control Plane (Multi-AZ)
    EKS-->>AWS: Create OIDC Provider
    Terraform->>EKS: Create Access Entry for Node Role

    Note over Terraform: Phase 5: Node Group
    Terraform->>AWS: Create Launch Template (40GB gp3, IMDSv2)
    Terraform->>EKS: Create Managed Node Group (2-4 t3.medium)
    EKS-->>AWS: Launch EC2 Instances
    AWS-->>Kubernetes: Instances Join Cluster

    Note over Terraform: Phase 6: IRSA
    Terraform->>Kubernetes: Create Service Account
    Terraform->>AWS: Create IAM Role for LB Controller
    Terraform->>AWS: Attach LB Controller Policy

    Note over Terraform: Phase 7: Ingress Controller
    Terraform->>Kubernetes: Deploy AWS LB Controller (Helm)
    Kubernetes-->>Kubernetes: 2 Controller Replicas Running

    Terraform-->>User: Deployment Complete
    User->>Kubernetes: Deploy App with Ingress
    Kubernetes->>AWS: LB Controller Creates ALB
    AWS-->>User: Application Accessible via ALB
```

---

## Network Architecture

### VPC Configuration (when vpc_create = true)

```mermaid
graph TB
    subgraph "VPC: 10.0.0.0/16"
        subgraph "Availability Zone 1"
            PubSub1[Public Subnet<br/>10.0.100.0/24<br/>Tagged: kubernetes.io/role/elb]
        end

        subgraph "Availability Zone 2"
            PubSub2[Public Subnet<br/>10.0.101.0/24<br/>Tagged: kubernetes.io/role/elb]
        end

        IGW[Internet Gateway]
        PubRT[Public Route Table<br/>0.0.0.0/0 → IGW]
    end

    Internet([Internet]) <--> IGW
    IGW <--> PubRT
    PubRT <--> PubSub1
    PubRT <--> PubSub2

    PubSub1 --> Nodes1[EKS Nodes<br/>with Public IPs]
    PubSub2 --> Nodes2[EKS Nodes<br/>with Public IPs]

    style PubSub1 fill:#4CAF50
    style PubSub2 fill:#4CAF50
    style IGW fill:#2196F3
```

### Network Flow

1. **Public Subnets**: 10.0.100.0/24 (AZ1) and 10.0.101.0/24 (AZ2)
2. **Internet Gateway**: Provides internet access for nodes
3. **Route Table**: Routes 0.0.0.0/0 to IGW for public internet access
4. **Subnet Tagging**:
   - `kubernetes.io/role/elb = "1"` - Allows ALB creation
   - `kubernetes.io/cluster/<cluster-name> = "owned"` - EKS ownership

---

## Security Groups

```mermaid
graph LR
    subgraph "Cluster Security Group"
        ClusterSG[eks-cluster-sg]
    end

    subgraph "Node Security Group"
        NodeSG[eks-node-sg]
    end

    Internet([Internet]) -->|HTTPS 443| ClusterSG

    ClusterSG -->|Egress 443| NodeSG
    ClusterSG -->|Egress 10250| NodeSG
    ClusterSG -->|Egress 1025-65535| NodeSG

    NodeSG -->|Ingress 443| ClusterSG
    NodeSG -->|Ingress 10250| ClusterSG
    NodeSG -->|Ingress 1025-65535| ClusterSG

    NodeSG -->|Ingress All Ports| NodeSG
    NodeSG -->|Egress All| Internet
    NodeSG -->|Egress 443| ClusterSG

    style ClusterSG fill:#FF9900
    style NodeSG fill:#3F8624
```

### Security Group Rules

**Cluster Security Group:**
- ✅ Egress to nodes on 443 (HTTPS)
- ✅ Egress to nodes on 10250 (kubelet API)
- ✅ Egress to nodes on 1025-65535 (ephemeral for CoreDNS)

**Node Security Group:**
- ✅ Ingress from cluster on 443, 10250, 1025-65535
- ✅ Ingress from other nodes on all ports (pod-to-pod)
- ✅ Egress to cluster on 443 (API server)
- ✅ Egress to internet on all ports (pull images, etc.)

---

## IAM Roles and Policies

```mermaid
graph TB
    subgraph "Cluster IAM Role"
        ClusterRole[eks-platform-est-dev-eks-cluster-role]
        CP1[AmazonEKSClusterPolicy]
        CP2[AmazonEKSVPCResourceController]
    end

    subgraph "Node IAM Role"
        NodeRole[eks-platform-est-dev-eks-node-role]
        NP1[AmazonEKSWorkerNodePolicy]
        NP2[AmazonEKS_CNI_Policy]
        NP3[AmazonEC2ContainerRegistryReadOnly]
        NP4[AmazonSSMManagedInstanceCore]
        NP5[AmazonEKSLoadBalancingPolicy]
        NP6[AmazonS3ReadOnlyAccess]
    end

    subgraph "LB Controller IAM Role"
        LBRole[eks-platform-est-dev-aws-lb-controller]
        LBPolicy[Custom LB Controller Policy<br/>3000+ lines]
    end

    subgraph "Trust Relationships"
        EKS[EKS Service]
        EC2[EC2 Service]
        OIDC[OIDC Provider<br/>sts:AssumeRoleWithWebIdentity]
    end

    EKS -->|AssumeRole| ClusterRole
    EC2 -->|AssumeRole| NodeRole
    OIDC -->|AssumeRole| LBRole

    ClusterRole --> CP1
    ClusterRole --> CP2

    NodeRole --> NP1
    NodeRole --> NP2
    NodeRole --> NP3
    NodeRole --> NP4
    NodeRole --> NP5
    NodeRole --> NP6

    LBRole --> LBPolicy

    style ClusterRole fill:#FF6B6B
    style NodeRole fill:#4ECDC4
    style LBRole fill:#95E1D3
```

### IAM Policy Details

**Cluster Role Policies:**
1. `AmazonEKSClusterPolicy` - Core EKS cluster operations
2. `AmazonEKSVPCResourceController` - VPC resource management (ENIs, security groups)

**Node Role Policies:**
1. `AmazonEKSWorkerNodePolicy` - Worker node operations
2. `AmazonEKS_CNI_Policy` - VPC CNI plugin for pod networking
3. `AmazonEC2ContainerRegistryReadOnly` - Pull images from ECR
4. `AmazonSSMManagedInstanceCore` - Systems Manager access for debugging
5. `AmazonEKSLoadBalancingPolicy` - Manage load balancers for services
6. `AmazonS3ReadOnlyAccess` - Pull artifacts from S3

**LB Controller Role:**
- Custom policy with 3000+ lines covering ALB/NLB/TargetGroup management

---

## IRSA (IAM Roles for Service Accounts)

```mermaid
sequenceDiagram
    participant Pod as Pod<br/>(aws-load-balancer-controller)
    participant K8s as Kubernetes<br/>Service Account
    participant OIDC as OIDC Provider<br/>(EKS)
    participant STS as AWS STS
    participant IAM as IAM Role
    participant AWS as AWS APIs<br/>(EC2, ELB, etc.)

    Note over Pod,K8s: Pod uses Service Account
    Pod->>K8s: Request credentials
    K8s->>Pod: Return OIDC token

    Note over Pod,STS: AssumeRoleWithWebIdentity
    Pod->>STS: AssumeRole with OIDC token
    STS->>OIDC: Validate token
    OIDC-->>STS: Token valid
    STS->>IAM: Check trust policy
    IAM-->>STS: Trust verified
    STS-->>Pod: Return temporary AWS credentials

    Note over Pod,AWS: Use AWS APIs
    Pod->>AWS: Create/Update ALB (with credentials)
    AWS-->>Pod: Success
```

### How IRSA Works

1. **Service Account**: Created in `kube-system` namespace with annotation pointing to IAM role ARN
2. **OIDC Provider**: EKS cluster has OIDC endpoint for token validation
3. **IAM Role**: Trust policy allows `sts:AssumeRoleWithWebIdentity` from OIDC provider
4. **Pod Authentication**: Pod presents OIDC token → STS validates → Returns temporary credentials
5. **AWS API Access**: Pod uses credentials to call AWS APIs (create ALB, modify target groups, etc.)

---

## AWS Load Balancer Controller

```mermaid
graph TB
    subgraph "Kubernetes Cluster"
        Ingress[Ingress Resource<br/>annotations:<br/>alb.ingress.kubernetes.io/scheme: internet-facing]
        Service[Service<br/>type: NodePort]
        Pods[Application Pods]

        subgraph "kube-system Namespace"
            AWSLBC1[AWS LB Controller<br/>Replica 1]
            AWSLBC2[AWS LB Controller<br/>Replica 2]
            SA[Service Account<br/>with IRSA]
        end
    end

    subgraph "AWS"
        ALB[Application Load Balancer]
        TG[Target Group<br/>NodePort targets]
        Nodes[EKS Nodes<br/>with NodePort]
        IAMRole[IAM Role<br/>LB Controller Policy]
    end

    AWSLBC1 --> SA
    AWSLBC2 --> SA
    SA --> IAMRole

    AWSLBC1 -.watches.-> Ingress
    AWSLBC2 -.watches.-> Ingress

    Ingress -.routes to.-> Service
    Service -.selects.-> Pods

    AWSLBC1 -->|Creates/Updates| ALB
    AWSLBC1 -->|Creates/Updates| TG

    ALB --> TG
    TG --> Nodes
    Nodes --> Service

    Internet([Internet]) --> ALB

    style AWSLBC1 fill:#326CE5
    style AWSLBC2 fill:#326CE5
    style ALB fill:#FF9900
```

### Load Balancer Controller Workflow

1. **Watch Ingress Resources**: Controller continuously watches for Ingress/Service changes
2. **Create ALB**: When Ingress is created, controller provisions ALB in AWS
3. **Configure Target Groups**: Creates target groups pointing to node IPs + NodePort
4. **Configure Listeners**: Sets up HTTP/HTTPS listeners based on Ingress rules
5. **Reconcile State**: Continuously syncs Kubernetes state with AWS resources
6. **Cleanup**: Deletes ALB/TGs when Ingress is removed

---

## Resource Creation Order

```mermaid
graph TD
    Start([terraform apply]) --> VPC[1. VPC & Networking<br/>VPC, Subnets, IGW, Routes]
    VPC --> IAM[2. IAM Roles<br/>Cluster Role, Node Role]
    IAM --> SG[3. Security Groups<br/>Cluster SG, Node SG]
    SG --> CW[4. CloudWatch Log Group]
    CW --> EKS[5. EKS Cluster<br/>Control Plane, OIDC]
    EKS --> AccessEntry[6. Access Entry<br/>Node Role Access]
    AccessEntry --> LT[7. Launch Template<br/>40GB gp3, IMDSv2]
    LT --> NodeGroup[8. Node Group<br/>2-4 t3.medium nodes]
    NodeGroup --> NodesJoin[9. Nodes Join Cluster<br/>EC2 → Kubernetes]
    NodesJoin --> IRSA[10. IRSA Setup<br/>Service Account + Role]
    IRSA --> Helm[11. Helm Deploy<br/>AWS LB Controller]
    Helm --> Ready[12. Cluster Ready<br/>Deploy Applications]

    style Start fill:#4CAF50
    style Ready fill:#4CAF50
    style EKS fill:#FF9900
    style NodeGroup fill:#3F8624
    style Helm fill:#326CE5
```

### Dependencies Explained

1. **VPC First**: Network infrastructure must exist before any resources
2. **IAM Before EKS**: Roles must exist for cluster/node creation
3. **Security Groups Before EKS**: SGs must exist to attach to cluster
4. **CloudWatch Before EKS**: Log group for control plane logs
5. **EKS Before Node Group**: Cluster must exist for nodes to join
6. **Access Entry After EKS**: Grants node role permission to join cluster
7. **Launch Template Before Node Group**: Template defines node configuration
8. **Nodes Before IRSA**: Cluster must be functional for service account creation
9. **IRSA Before Helm**: Service account needed for LB controller
10. **Helm Last**: Controller deployed after all infrastructure ready

---

## How Resources Are Deployed

### Step 1: Initialize Terraform

```bash
cd /workspaces/dev-container-terraform/terraform-aws-projects/aws-eks/branches/tech-branch-est/dev
terraform init
```

**What happens:**
- Downloads AWS provider plugin
- Initializes backend (local or S3)
- Downloads module dependencies

### Step 2: Review Configuration

Key files:
- `terraform.tfvars` - Variable values (cluster version, region, etc.)
- `main.tf` - Module orchestration
- `variables.tf` - Variable definitions

### Step 3: Plan Deployment

```bash
terraform plan --profile default-est-2
```

**Terraform calculates:**
- Resources to create: ~45 resources
- Dependencies between resources
- Order of operations

### Step 4: Apply Configuration

```bash
terraform apply --profile default-est-2
```

**Deployment timeline (approximate):**
- VPC & Networking: 2-3 minutes
- IAM Roles: 1 minute
- EKS Cluster: 10-15 minutes (AWS provisions control plane)
- Node Group: 5-10 minutes (EC2 instances launch and join)
- IRSA: 1 minute
- Helm (LB Controller): 2-3 minutes

**Total: ~25-35 minutes**

---

## Configuration Options

### VPC Creation (Option 1: Create New VPC)

```hcl
module "eks_cluster" {
  vpc_create              = true              # Create new VPC
  vpc_cidr                = "10.0.0.0/16"     # VPC CIDR
  availability_zone_count = 2                 # Number of AZs
  create_private_subnets  = false             # Public only
}
```

### VPC Creation (Option 2: Use Existing VPC)

```hcl
module "eks_cluster" {
  vpc_create = false                          # Use existing VPC
  vpc_id     = "vpc-xxxxx"                    # Existing VPC ID
  subnet_ids = ["subnet-aaa", "subnet-bbb"]   # Existing subnet IDs
}
```

### Node Group Sizing

```hcl
module "eks_node_group_system" {
  instance_types = ["t3.medium"]              # Instance type
  disk_size      = 40                         # EBS volume size (GB)
  disk_type      = "gp3"                      # Volume type

  capacity_type  = "ON_DEMAND"                # ON_DEMAND or SPOT
  desired_size   = 2                          # Desired node count
  min_size       = 2                          # Minimum nodes
  max_size       = 4                          # Maximum nodes
}
```

---

## Cost Breakdown (Monthly Estimates)

| Resource | Configuration | Monthly Cost |
|----------|---------------|--------------|
| **EKS Control Plane** | 1 cluster | ~$73.00 |
| **EC2 Nodes** | 2x t3.medium (on-demand) | ~$60.00 |
| **EBS Volumes** | 2x 40GB gp3 | ~$6.40 |
| **Data Transfer** | Variable | ~$5-10 |
| **CloudWatch Logs** | Control plane logs | ~$2-5 |
| **ALB** | Per load balancer | ~$16-25 |
| **VPC** | VPC, subnets, IGW | $0 (free) |
| | **Total (without ALB)** | **~$141-144** |
| | **Total (with 1 ALB)** | **~$157-169** |

**Cost Optimization Tips:**
- Use Spot instances for non-critical workloads (50-70% savings on EC2)
- Right-size instance types based on actual usage
- Enable Cluster Autoscaler to scale nodes down during low traffic
- Use Savings Plans or Reserved Instances for predictable workloads
- Set CloudWatch log retention to 7-14 days instead of forever

---

## Accessing the Cluster

### Configure kubectl

```bash
aws eks update-kubeconfig --name eks-platform-est-dev-eks --region us-east-2 --profile default-est-2
```

### Verify Cluster Access

```bash
# Check cluster info
kubectl cluster-info

# List nodes
kubectl get nodes

# Check AWS LB Controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# View controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=50
```

---

## Deploying Applications with Ingress

### Example: Deploy Sample App with ALB

```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/healthcheck-path: /
spec:
  ingressClassName: alb
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx-service
            port:
              number: 80
```

**What happens:**
1. Deployment creates 3 nginx pods
2. Service exposes pods via NodePort
3. Ingress triggers AWS LB Controller
4. Controller creates ALB in AWS
5. ALB routes traffic to node IPs + NodePort
6. Nodes forward to nginx pods

**Get ALB URL:**
```bash
kubectl get ingress nginx-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

---

## Troubleshooting

### Nodes Not Joining Cluster

**Symptoms:** Node group status is `CREATE_FAILED` with "NodeCreationFailure"

**Common causes:**
1. ❌ Nodes don't have public IPs (fixed by removing network_interfaces block)
2. ❌ Access entry missing or misconfigured
3. ❌ Security groups blocking kubelet communication
4. ❌ IAM instance profile not attached

**Diagnosis:**
```bash
# Check node group status
aws eks describe-nodegroup --cluster-name <cluster> --nodegroup-name <nodegroup>

# Check instance details
aws ec2 describe-instances --instance-ids <id>

# Check access entries
aws eks list-access-entries --cluster-name <cluster>
```

### Helm Chart Conflicts

**Symptom:** `ServiceAccount exists and cannot be imported`

**Cause:** IRSA module creates service account, Helm also tries to create it

**Fix:** Set `serviceAccount.create = false` in Helm values

### ALB Not Created

**Symptoms:** Ingress created but no ALB in AWS

**Diagnosis:**
```bash
# Check controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Common issues:
# - Missing subnet tags (kubernetes.io/role/elb)
# - IAM permissions insufficient
# - Ingress annotations incorrect
```

---

## Module Variables Reference

### eks-cluster Module

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `project_name` | string | - | Project identifier |
| `environment` | string | - | Environment (dev/staging/prod) |
| `branch_identifier` | string | - | Branch identifier |
| `cluster_version` | string | "1.34" | Kubernetes version |
| `vpc_create` | bool | false | Create new VPC |
| `vpc_cidr` | string | "10.0.0.0/16" | VPC CIDR block |
| `vpc_id` | string | null | Existing VPC ID |
| `subnet_ids` | list(string) | null | Existing subnet IDs |
| `cluster_endpoint_public_access` | bool | true | Enable public API access |
| `enabled_cluster_log_types` | list(string) | [] | Control plane log types |

### eks-node-group Module

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `cluster_name` | string | - | EKS cluster name |
| `node_role_arn` | string | - | Node IAM role ARN |
| `subnet_ids` | list(string) | - | Subnet IDs for nodes |
| `instance_types` | list(string) | ["t3.medium"] | Instance types |
| `disk_size` | number | 40 | EBS volume size (GB) |
| `capacity_type` | string | "ON_DEMAND" | ON_DEMAND or SPOT |
| `desired_size` | number | 2 | Desired node count |
| `min_size` | number | 2 | Minimum nodes |
| `max_size` | number | 4 | Maximum nodes |

---

## Security Best Practices

### ✅ Implemented

- **Encrypted EBS volumes** - All node volumes encrypted at rest
- **IMDSv2 enforced** - Prevents SSRF attacks on instance metadata
- **Least privilege IAM** - Only necessary policies attached
- **Security groups** - Restrict traffic to required ports only
- **Private subnets option** - Can deploy nodes in private subnets with NAT
- **IRSA** - Service accounts use temporary credentials, not node role
- **API authentication** - `API_AND_CONFIG_MAP` mode with access entries

### 🔒 Additional Recommendations

1. **Enable EKS secrets encryption** - Use KMS to encrypt Kubernetes secrets
2. **Enable VPC flow logs** - Audit network traffic
3. **Use private endpoints** - Disable public cluster endpoint for production
4. **Implement Pod Security Standards** - Enforce pod security policies
5. **Enable audit logging** - Send to CloudWatch for compliance
6. **Network policies** - Restrict pod-to-pod communication
7. **RBAC** - Implement least-privilege Kubernetes RBAC

---

## Maintenance Operations

### Upgrade Kubernetes Version

```bash
# Update variable
# In variables.tf: cluster_version = "1.35"

terraform plan
terraform apply

# Update nodes (requires rolling update)
# Node group will be recreated with new version
```

### Scale Node Group

```bash
# Update in main.tf
desired_size = 4
max_size     = 6

terraform apply
```

### Update Launch Template

Changes to launch template trigger node group replacement:
- Disk size change
- Instance type change
- Security groups change

**Terraform will:**
1. Create new launch template version
2. Create new node group
3. Drain old nodes
4. Delete old node group

---

## Outputs

After deployment, Terraform outputs:

| Output | Description | Example |
|--------|-------------|---------|
| `cluster_name` | EKS cluster name | eks-platform-est-dev-eks |
| `cluster_endpoint` | API server endpoint | https://xxx.eks.amazonaws.com |
| `cluster_version` | Kubernetes version | 1.34 |
| `configure_kubectl` | kubectl config command | aws eks update-kubeconfig... |
| `oidc_provider_arn` | OIDC provider ARN | arn:aws:iam::xxx:oidc-provider/... |
| `vpc_id` | VPC ID | vpc-084f63964b2b6241e |
| `subnet_ids` | Subnet IDs | ["subnet-xxx", "subnet-yyy"] |

---

## Summary

This infrastructure provides a **production-ready EKS cluster** with:

- ✅ **High Availability** - Multi-AZ deployment with managed node groups
- ✅ **Security** - Encrypted volumes, IMDSv2, least-privilege IAM, IRSA
- ✅ **Scalability** - Auto-scaling groups, load balancer controller
- ✅ **Observability** - CloudWatch logs, Kubernetes metrics
- ✅ **Modularity** - Reusable modules for different environments
- ✅ **Flexibility** - Optional VPC creation, configurable sizing
- ✅ **Cost-Optimized** - Right-sized instances, spot support, cleanup policies

**Total Resources Created:** ~45 AWS resources
**Deployment Time:** ~25-35 minutes
**Monthly Cost:** ~$141-169 (dev environment)

---

## Next Steps

1. **Deploy sample application** with Ingress to test ALB creation
2. **Set up monitoring** with Prometheus + Grafana
3. **Configure Cluster Autoscaler** for dynamic node scaling
4. **Implement GitOps** with ArgoCD or Flux
5. **Add additional node groups** for different workload types (spot, GPU, etc.)
6. **Enable secrets encryption** with AWS KMS
7. **Configure backup** with Velero
8. **Set up CI/CD pipeline** for automated deployments

---

**Questions or Issues?** Check the troubleshooting section or review Terraform logs with `TF_LOG=DEBUG terraform apply`
