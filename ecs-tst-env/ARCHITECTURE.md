# Architecture — ecs-tst-env

How the ECS-on-Fargate infrastructure is designed, why it's split the way it is, and how a
container image travels from source code to a running task.

For setup and commands, see **[README.md](./README.md)**.

---

## 1. Design at a glance

The system is built from four **reusable modules** that are composed into **per-environment
root stacks** under a **per-client** branch:

```text
modules/  ──(source = ...)──►  branch/<client>/<stack>/env/<env>/
(generic, reusable)            (concrete: real names, CIDRs, regions, backends)
```

Two ideas drive the layout:

1. **Module/usage separation.** Modules know *how* to build a thing (a VPC, a cluster, a
   service). Root stacks decide *what* to build for a given client/environment. This keeps
   environments DRY — they differ by inputs (`tfvars`/locals), not by copied resource blocks.

2. **Two stacks per environment** with separate state — a long-lived **infra** layer and a
   faster-moving **platform** layer — connected by remote-state outputs.

---

## 2. The two-stack model

```text
┌──────────────────────────── infra stack ─────────────────────────────┐
│  networking (VPC, subnets, IGW, routes)                               │
│  ecs-cluster (FARGATE + FARGATE_SPOT)                                  │
│  ecr (image repository)                                               │
│                                                                       │
│  outputs:  vpc_id, public_subnet_ids, private_subnet_ids,             │
│            ecs_cluster_id, ecr_api_repository_url                      │
└───────────────────────────────┬───────────────────────────────────────┘
                                 │  terraform_remote_state (reads S3 state)
                                 ▼
┌────────────────────────── platform stack ────────────────────────────┐
│  ecs-service  (for_each over local.services = { app1, app2 })         │
│    task definition + service + security group + IAM roles + logs      │
│                                                                       │
│  reads infra outputs; never re-declares VPC/cluster/ECR               │
└───────────────────────────────────────────────────────────────────────┘
```

**Why split?**

- **Blast radius.** Re-deploying an app (platform) can't accidentally touch the VPC or
  cluster (infra). The destructive surface of day-to-day deploys is small.
- **Lifecycle mismatch.** Networking and clusters change rarely; services change on every
  release. Separate state means separate plans, locks, and apply cadence.
- **Clear contract.** The infra stack's outputs are the only thing the platform stack may
  depend on — no hardcoded VPC/subnet/repo IDs leak across the boundary.

The dependency is enforced by `data.terraform_remote_state.infra` in
`platform/env/dev/data.tf`, which reads the infra stack's S3 state object directly. **Infra
must be applied first**, or the platform plan has nothing to read.

---

## 3. State management

- **Backend:** S3, one state object per stack per environment.
  - dev bucket `damtechguy-tf-state-dev` (`us-west-2`); prd bucket `damtechguy-tf-state-prd` (`us-east-2`).
- **Locking:** `use_lockfile = true` — **S3-native state locking** (Terraform ≥ 1.10), so no
  DynamoDB lock table is required.
- **Encryption:** `encrypt = true` on every backend.
- **Isolation:** each `(client, env, stack)` triple has its own key, e.g.
  `client1/dev/platform/client1-platform-dev.tfstate`. Nothing is shared across environments.

---

## 4. Modules

### `modules/networking`
A self-contained VPC:

- One VPC (`enable_dns_hostnames/support = true`).
- **2 public + 2 private subnets** spread across exactly **2 AZs** (validated) for HA.
- Internet Gateway + a public route table (`0.0.0.0/0 → IGW`) associated to public subnets.
- Public subnets set `map_public_ip_on_launch = true`.
- **No NAT gateway** — private subnets currently have no egress route. This is a deliberate
  dev cost choice; it's also why dev tasks run in *public* subnets (so they can reach ECR).

Outputs: `vpc_id`, `vpc_cidr_block`, `public_subnet_ids`, `private_subnet_ids`,
`internet_gateway_id`, `public_route_table_id`.

### `modules/ecs-cluster`
- An ECS cluster with both **FARGATE** and **FARGATE_SPOT** capacity providers registered.
- A configurable `default_capacity_provider` and a `containerInsights` toggle.
- The `cluster_id` output carries a `depends_on` the capacity-provider association, so
  consuming services don't start before Spot/On-Demand capacity is wired up.

### `modules/ecr`
- One image repository with **scan-on-push**, configurable **tag mutability**
  (default `IMMUTABLE`), and at-rest **encryption** (`AES256` default, or `KMS`).
- A **lifecycle policy**: keep the last *N* tagged images (default 30) and expire untagged
  images after *N* days (default 14) — keeps storage cost bounded.
- `force_delete` is available but defaults to off (so a repo with images isn't dropped by
  accident).

### `modules/ecs-service`
The workhorse. For a single service it creates:

- A **CloudWatch log group** (`/ecs/<name_prefix>`) with enforced retention.
- A **security group**: ingress from per-app **structured rules**
  (`{ cidr, from_port, to_port, protocol }` via `ingress_rules`), plus all-egress (for ECR
  pulls and AWS API calls). Each app can open a different set of ports/CIDRs.
- A **task definition** — Fargate, `awsvpc` networking, Linux/X86_64, with a single container
  whose image, port, env vars, secrets, and CPU/memory are inputs; logs go to the awslogs driver.
- An **ECS service** with:
  - `deployment_circuit_breaker { enable, rollback }` — a bad deploy auto-rolls back.
  - `capacity_provider_strategy` chosen from `use_fargate_spot` (Spot vs On-Demand).
  - `lifecycle { ignore_changes = [desired_count] }` — so the autoscaler (below) owns the live
    task count without fighting Terraform.
- **Application Auto Scaling** (created only when both `min_count` and `max_count` are set):
  an `aws_appautoscaling_target` bounding the service to `[min_count, max_count]` and a
  target-tracking `aws_appautoscaling_policy` on average CPU% (`autoscaling_cpu_target`).
- **IAM roles** (least-privilege):
  - *Execution role* — `AmazonECSTaskExecutionRolePolicy` for image pulls + logs, plus a
    scoped inline policy granting `ssm:GetParameters` / `secretsmanager:GetSecretValue` /
    `kms:Decrypt` **only** for the specific secret ARNs passed in.
  - *Task role* — the role the app assumes at runtime (optional; auto-created empty unless you
    pass your own). ECS Exec permissions are added only when `enable_execute_command = true`.

---

## 5. From code to running task

```text
 services/<app>/            services/deploy.sh           ECR repo
 ┌───────────┐   docker     ┌──────────────────┐  push   ┌──────────────────────────┐
 │ Dockerfile│──build──────►│ tag = <app>-<hex>│────────►│ client1-…-api:hello-app1-…│
 │ index.html│              │       -<date>    │         │ client1-…-api:super-app2-…│
 └───────────┘              └──────────────────┘         └────────────┬─────────────┘
                                                                       │
        terraform apply (platform stack)                              │ describe-images
        ┌───────────────────────────────────────────┐                │
        │ data.external.latest_image[app]            │  newest tag    │
        │   → services/latest-ecr-tag.sh ────────────┼────────────────┘
        │       (filter by prefix, sort by pushedAt) │
        │                                            │
        │ module.ecs_service["app1"] / ["app2"]      │ image = repo_url:<resolved tag>
        │   task definition ─► ECS service ─► tasks  │
        └───────────────────────────────────────────┘
```

### The apps
`services/hello-app` (App1) and `services/super-app` (App2) are tiny static sites served by
`nginx:1.27-alpine`, each with its own `Dockerfile` and `deploy.sh`.

### Build & push (`deploy.sh`)
Builds the image with `docker buildx` and pushes it to the shared ECR repo under a unique,
immutable tag of the form `<APP_NAME>-<random hex>-<UTC datestamp>`. It **does not touch
ECS** — task definitions and services are owned by Terraform. It prints the resulting tag as
JSON on stdout.

### Image selection (auto-latest)
The platform stack does **not** take an image tag as input. Instead, for each entry in
`local.services` it runs an `external` data source backed by `services/latest-ecr-tag.sh`:

```text
local.services = {
  app1 = {
    image_prefix = "hello-app1", container_port = 80
    task_cpu = 256, task_memory = 512
    desired_count = 2, min_count = 2, max_count = 6, cpu_target = 70
    ingress_rules = [{ cidr = "0.0.0.0/0", from_port = 80, to_port = 80, protocol = "tcp" }]
  }
  app2 = { image_prefix = "super-app2", container_port = 80, ... }   # different sizing/scaling/ingress
}
```

Each app is configured independently — sizing (`task_cpu`/`task_memory`), task count and
autoscaling bounds (`desired_count`/`min_count`/`max_count`/`cpu_target`), and security-group
openings (`ingress_rules`) are all per-app.

`latest-ecr-tag.sh` calls `aws ecr describe-images`, keeps tags starting with the service's
`image_prefix`, sorts by `imagePushedAt`, and returns the newest. The service's
`container_image` becomes `<ecr_api_repository_url>:<resolved tag>`.

**Consequence:** pushing a new image and re-running `terraform apply` rolls the service to
the latest build with no manual tag wrangling — but because resolution happens at *plan
time*, plans are not perfectly reproducible. That's an accepted trade-off in dev; pin
explicit tags for staging/prod.

### Adding an app
Add one entry to `local.services` (its `image_prefix` + `container_port`). The `for_each`
service module and the `external` resolver expand automatically — no copied resource blocks.

---

## 6. How the design maps to priorities

**Security**
- Least-privilege IAM: execution role uses the AWS-managed execution policy plus a
  secret-scoped inline policy; task role is empty by default.
- ECR scan-on-push + immutable tags (prevents tag hijacking); at-rest encryption everywhere.
- S3 state is encrypted and locked.
- ⚠️ Dev exposes tasks publicly (`0.0.0.0/0:80`, public IPs). Acceptable for a throwaway dev
  env; **front with an ALB and move to private subnets for anything real.**

**High availability**
- Subnets span 2 AZs (validated); services start at `desired_count` and scale within
  `[min_count, max_count]` via CPU target-tracking autoscaling.
- Deployment circuit breaker with auto-rollback.
- Cluster waits for capacity providers before services attach.

**Cost**
- Fargate **Spot** in dev (~70% cheaper); no NAT gateway; ECR + CloudWatch lifecycle/retention
  caps storage. Everything is tagged (`Client`, `Project`, `Environment`, `ManagedBy`,
  `CostCenter`, `Region`) via provider `default_tags` for cost allocation.

**Maintainability**
- Reusable modules + `for_each` services; environments differ by inputs, not duplication.
- Remote-state contract keeps cross-stack references explicit.

---

## 7. Known gaps / TODO

- **stg / prd are incomplete.** Both infra dirs deploy **networking only** — no ECR, cluster,
  or services — and there are no `platform/env/stg` or `platform/env/prd` stacks.
- **Naming is inconsistent across stacks/envs.** infra-dev uses prefix
  `client1-ecs-app-infra-dev` (project `ecs-app`), while platform-dev uses `client1-infra-dev`
  (project `infra`); stg/prd locals use yet another pattern and prd has a stray `project_name2`.
  Resource names still work, but the "shared prefix" comment in platform locals is aspirational.
- **No ALB / DNS.** Apps are reached by raw task public IPs today.
- **No NAT / VPC endpoints**, so private subnets are currently unusable for outbound traffic.
- **Auto-latest is unpinned** (see §5) — add explicit tag pinning before promoting beyond dev.
- The per-app `deploy.sh` header comments still reference the retired
  `-var container_image_tag` apply flow.
