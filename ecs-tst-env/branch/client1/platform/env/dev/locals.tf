locals {
  client_name  = "client1"
  project_name = "Applications" # keep aligned with the infra stack so resource names match (e.g. cluster + service share "client1-infra-dev" prefix)
  stack        = "platform"
  environment  = "dev"
  region       = "us-west-2"

  naming_prefix = "${local.client_name}-${local.project_name}-${local.environment}"

  # Shared ECR repo (both apps live here, distinguished by tag prefix).
  api_repo_url  = data.terraform_remote_state.infra.outputs.ecr_api_repository_url
  api_repo_name = split("/", local.api_repo_url)[1] # strip the registry host -> "client1-...-api"

  # One ECS service per app. Every app is configured independently here:
  #   image_prefix   - matched against ECR tags; newest match is deployed (data.external.latest_image)
  #   container_port - port the container listens on
  #   task_cpu/memory- per-task Fargate sizing (must be a valid Fargate combo)
  #   desired/min/max_count - starting count + autoscaling bounds (min+max => autoscaling on)
  #   cpu_target     - target avg CPU% for the autoscaling policy
  #   ingress_rules  - per-app security group openings { cidr, from_port, to_port, protocol }
  services = {
    # Public-facing web app: open to the internet, scales 2..6 on CPU.
    app1 = {
      image_prefix   = "hello-app1"
      container_port = 80

      task_cpu    = 256
      task_memory = 512

      desired_count = 2
      min_count     = 2
      max_count     = 6
      cpu_target    = 70

      ingress_rules = [
        { cidr = "0.0.0.0/0", from_port = 80, to_port = 80, protocol = "tcp", description = "public web" },
      ]
    }

    # Internal app: larger task, locked to the VPC range, scales 1..3 at a tighter CPU target.
    app2 = {
      image_prefix   = "super-app2"
      container_port = 80

      task_cpu    = 512
      task_memory = 1024

      desired_count = 1
      min_count     = 1
      max_count     = 3
      cpu_target    = 60

      ingress_rules = [
        { cidr = "0.0.0.0/0", from_port = 80, to_port = 80, protocol = "tcp", description = "Public access" },
        { cidr = "10.0.0.0/8", from_port = 8080, to_port = 8080, protocol = "tcp", description = "admin port from corp" },
      ]
    }
  }

  cost_center = "infra-${local.environment}"

  common_tags = {
    Client      = local.client_name
    Project     = local.project_name
    Stack       = local.stack
    Environment = local.environment
    ManagedBy   = "terraform"
    CostCenter  = local.cost_center
    Region      = local.region
  }
}
