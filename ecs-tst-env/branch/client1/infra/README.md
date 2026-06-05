# Infra Layer — `client1`

The **foundation** layer. It provisions the long-lived, slow-changing resources that
everything else builds on: the **network**, the **ECS cluster**, and the **ECR repository**.
The [platform layer](../platform/README.md) consumes this layer's outputs and must be applied
*after* it.

> Part of [ecs-tst-env](../../../README.md). For the cross-layer design see
> [ARCHITECTURE.md](../../../ARCHITECTURE.md).

---

## What this layer owns

| Module        | Resource(s)                                                        | Purpose                              |
|---------------|-------------------------------------------------------------------|--------------------------------------|
| `networking`  | VPC, 2× public + 2× private subnets (2 AZ), IGW, public route table | Where tasks run                      |
| `ecs-cluster` | ECS cluster + `FARGATE` / `FARGATE_SPOT` capacity providers        | Compute pool for services            |
| `ecr`         | Image repository (scan-on-push, lifecycle, encryption)            | Stores the app container images      |

It owns **no services** — those live in the platform layer.

---

## Composition

```mermaid
graph TD
    subgraph root["infra/env/dev (root stack)"]
        locals["locals.tf<br/>names · region · tags"]
        data["data.tf<br/>azs · caller identity"]
    end

    root -->|"source = ../../../../modules/*"| net["module.networking"]
    root --> cluster["module.ecs_cluster"]
    root --> ecr["module.ecr_api"]

    net --> vpc["aws_vpc + subnets<br/>IGW + route table"]
    cluster --> ecsc["aws_ecs_cluster<br/>+ capacity_providers"]
    ecr --> repo["aws_ecr_repository<br/>+ lifecycle_policy"]

    vpc --> out["outputs.tf"]
    ecsc --> out
    repo --> out

    out -.->|"read via terraform_remote_state"| platform["platform layer"]
```

---

## Network topology (dev)

```mermaid
graph TB
    igw["Internet Gateway"]

    subgraph vpc["VPC 172.20.0.0/16 (dev)"]
        subgraph azA["AZ us-west-2a"]
            puba["public subnet<br/>map_public_ip = true"]
            priva["private subnet<br/>(no NAT route)"]
        end
        subgraph azB["AZ us-west-2b"]
            pubb["public subnet<br/>map_public_ip = true"]
            privb["private subnet<br/>(no NAT route)"]
        end
        rt["public route table<br/>0.0.0.0/0 → IGW"]
    end

    internet(("Internet")) --- igw
    igw --- rt
    rt --- puba
    rt --- pubb

    classDef pub fill:#1d4ed8,color:#fff,stroke:#1e3a8a;
    classDef priv fill:#334155,color:#fff,stroke:#0f172a;
    class puba,pubb pub;
    class priva,privb priv;
```

> ⚠️ **No NAT gateway.** Private subnets have no outbound route today, which is why dev tasks
> run in the **public** subnets (so they can pull from ECR). Add NAT or VPC endpoints and move
> tasks to private subnets before promoting beyond dev.

---

## Outputs (the contract with platform)

These are the only values the platform layer is allowed to depend on:

```mermaid
graph LR
    subgraph infra["infra outputs"]
        o1["vpc_id"]
        o2["public_subnet_ids"]
        o3["private_subnet_ids"]
        o4["ecs_cluster_id"]
        o5["ecs_cluster_name"]
        o6["ecr_api_repository_url"]
    end
    infra -->|terraform_remote_state.infra| platform["platform/env/dev"]
```

| Output                   | Consumed by platform for                          |
|--------------------------|---------------------------------------------------|
| `vpc_id`                 | service security group                            |
| `public_subnet_ids`      | task placement (`assign_public_ip = true`)        |
| `private_subnet_ids`     | (available; unused in dev)                        |
| `ecs_cluster_id`         | where services attach                             |
| `ecr_api_repository_url` | base of the image reference + tag resolution      |

---

## Environment matrix

| Env   | Region      | VPC CIDR        | networking | ecs-cluster | ecr | State key                                    |
|-------|-------------|-----------------|:----------:|:-----------:|:---:|----------------------------------------------|
| `dev` | `us-west-2` | `172.20.0.0/16` | ✅         | ✅          | ✅  | `client1/dev/infra/client1-infra-dev.tfstate`|
| `stg` | `us-east-1` | `172.22.0.0/16` | ✅         | ❌          | ❌  | `client1/stg/...` *(scaffold)*               |
| `prd` | `us-east-2` | `172.21.0.0/16` | ✅         | ❌          | ❌  | `client1/prd/client1-prd.tfstate` *(scaffold)*|

> ⚠️ Only **dev** is fully wired. `stg` and `prd` currently apply **networking only** and use a
> different (`infra`) project name + naming pattern than dev (`ecs-app`).

---

## Apply

```bash
cd env/dev
terraform init
terraform plan
terraform apply
```

State: S3 backend with native lockfile (`use_lockfile = true`), encrypted. Apply this layer
**before** the platform layer; destroy it **after**.

```mermaid
sequenceDiagram
    participant Op as Operator
    participant Infra as infra/env/dev
    participant AWS
    participant Plat as platform/env/dev

    Op->>Infra: terraform apply
    Infra->>AWS: create VPC, cluster, ECR
    Infra-->>Op: outputs (vpc/subnets/cluster/ecr)
    Note over Plat: reads these via remote state
    Op->>Plat: terraform apply (next layer)
```
