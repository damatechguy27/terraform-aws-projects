# ecs-tst-env — ECS on Fargate (Terraform)

Terraform infrastructure that runs containerized apps on **AWS ECS Fargate**, fronted by
a from-scratch VPC, with images stored in **ECR**. Built as reusable modules and composed
per client / per environment.

This repo currently provisions one client (`client1`) running two demo web apps
(`app1` / `app2`) on a shared cluster in the `dev` environment.

> For the design rationale, data flow, and deeper detail, see **[ARCHITECTURE.md](./ARCHITECTURE.md)**.

---

## TL;DR

```text
ECR (images)  ──►  ECS Fargate service(s)  ──►  tasks in a custom VPC (public subnets)
        ▲                     ▲
        │                     │
   deploy.sh             Terraform (infra + platform stacks)
```

Two Terraform "stacks" per environment:

| Stack        | Owns                                              | State key (dev)                              |
|--------------|---------------------------------------------------|----------------------------------------------|
| **infra**    | VPC, subnets, IGW, ECS **cluster**, **ECR** repo  | `client1/dev/infra/client1-infra-dev.tfstate`    |
| **platform** | ECS **services** + task definitions (the apps)    | `client1/dev/platform/client1-platform-dev.tfstate` |

The platform stack reads the infra stack's outputs via `terraform_remote_state`, so
**infra must be applied before platform**.

---

## Repository layout

```text
ecs-tst-env/
├── README.md                  # this file
├── ARCHITECTURE.md            # design & how it works
├── modules/                   # reusable building blocks
│   ├── networking/            # VPC, public/private subnets (2 AZ), IGW, route tables
│   ├── ecs-cluster/           # ECS cluster + FARGATE / FARGATE_SPOT capacity providers
│   ├── ecr/                   # ECR repo: scan-on-push, lifecycle policy, encryption
│   └── ecs-service/           # task def + service + SG + IAM roles + log group
└── branch/
    └── client1/               # one folder per client
        ├── infra/env/
        │   ├── dev/           # ✅ fully wired: networking + ECR + cluster
        │   ├── stg/           # ⚠️ scaffolded: networking only
        │   └── prd/           # ⚠️ scaffolded: networking only
        ├── platform/env/
        │   └── dev/           # ✅ ECS services app1 + app2 (for_each)
        └── services/          # application source + deploy tooling
            ├── hello-app/     # "App1" — static nginx site (+ deploy.sh, dockerfile)
            ├── super-app/     # "App2" — static nginx site (+ deploy.sh, dockerfile)
            └── latest-ecr-tag.sh  # resolves newest image tag by prefix (used by Terraform)
```

Each `env/<name>` directory is a standard root module: `main.tf`, `locals.tf`,
`providers.tf`, `backend.tf`, `data.tf`, `vars.tf`, and (for the wired ones) `outputs.tf`.

---

## Prerequisites

- **Terraform** ≥ 1.7 (the S3 backend uses `use_lockfile`, which needs Terraform ≥ 1.10)
- **AWS CLI v2**, authenticated to the target account (region varies per env — see below)
- **Docker** with `buildx` (for building/pushing app images)
- **jq** and **openssl** (used by the deploy + tag-resolver scripts)
- Pre-existing S3 state buckets: `damtechguy-tf-state-dev`, `damtechguy-tf-state-prd`

Per-environment regions: **dev** = `us-west-2`, **stg** = `us-east-1`, **prd** = `us-east-2`.

---

## Quickstart (dev)

All paths below are relative to `branch/client1/`.

### 1. Stand up the foundation (infra stack)

```bash
cd infra/env/dev
terraform init
terraform apply        # creates VPC, subnets, IGW, ECS cluster, ECR repo
```

### 2. Build & push the app images

The apps share one ECR repo (the infra stack's `ecr_api_repository_url`). Each push gets a
unique, immutable tag prefixed with the app name (e.g. `hello-app1-<hex>-<date>`).

```bash
cd ../../../services            # branch/client1/services
export AWS_REGION=us-west-2
export ECR_REPO_URL=$(terraform -chdir=../infra/env/dev output -raw ecr_api_repository_url)

# App1
APP_NAME=hello-app1 BUILD_CONTEXT=$PWD/hello-app ./hello-app/deploy.sh

# App2
APP_NAME=super-app2 BUILD_CONTEXT=$PWD/super-app ./super-app/deploy.sh
```

### 3. Deploy the services (platform stack)

```bash
cd ../platform/env/dev          # branch/client1/platform/env/dev
terraform init
terraform apply                 # creates one ECS service per app
```

At plan time, Terraform calls `services/latest-ecr-tag.sh` to find the **newest pushed
image** matching each app's prefix and points that service's task definition at it — so
re-running `apply` after a new `deploy.sh` push rolls the service automatically. No image
tag is passed by hand.

### 4. Find the running apps

```bash
terraform output service_names      # ECS service names
terraform output deployed_images    # the exact image each service is running
```

Tasks run in **public subnets with public IPs** (dev only, no NAT) and the service SG
allows `:80` from `0.0.0.0/0`. Grab a task's public IP from the ECS console (or
`aws ecs ...`) and open it in a browser.

---

## Common operations

| Goal                              | Command (from the relevant `env` dir)                          |
|-----------------------------------|----------------------------------------------------------------|
| Preview changes                   | `terraform plan`                                               |
| Ship a new app version            | re-run that app's `deploy.sh`, then `terraform apply` (platform) |
| Add a third app                   | add an entry to `local.services` in `platform/env/dev/locals.tf` |
| Inspect what's deployed           | `terraform output deployed_images` (platform)                  |
| Format / validate                 | `terraform fmt -recursive` · `terraform validate`              |
| Tear down (reverse order)         | `terraform destroy` in **platform**, then **infra**            |

---

## Status & caveats

- **Only `dev` is fully functional.** `stg` and `prd` infra dirs currently provision
  **networking only** — no ECR, cluster, or services yet, and there is no `platform/env/stg`
  or `platform/env/prd`.
- **No NAT gateway.** Private subnets exist but have no internet route; dev tasks run in
  **public** subnets with public IPs to reach ECR cheaply. Production should add NAT (or VPC
  endpoints) and move tasks to private subnets behind an ALB.
- **Auto-latest images are not pinned.** The platform stack resolves "newest matching image"
  at plan time, so applies are not perfectly reproducible. Fine for dev; pin explicit tags for prod.
- The per-app `deploy.sh` header comments still describe the older `-var container_image_tag`
  workflow; image selection is now automatic (see [ARCHITECTURE.md](./ARCHITECTURE.md)).

See **[ARCHITECTURE.md](./ARCHITECTURE.md)** for the full design, module reference, and
security/HA/cost notes.
