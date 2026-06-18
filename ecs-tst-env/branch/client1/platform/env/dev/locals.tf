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
  #   ingress_rules  - per-app security group openings { cidr, from_port, to_port, protocol }
  #
  # Autoscaling uses STEP scaling on CPU (module defaults, tunable per app via the
  # autoscaling_* module inputs in main.tf):
  #   scale OUT +1 task when CPU > 70% for 3 of the last 5 one-minute datapoints
  #   scale IN  -1 task when CPU < 70% for 10 one-minute datapoints (10 min)
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

      # Scale out when cpu > 70% for 3 of 5 datapoints (defaults, tunable per app here)
      autoscaling_high_threshold           = 70
      autoscaling_high_datapoints_to_alarm = 3
      autoscaling_high_evaluation_periods  = 5
      autoscaling_high_period              = 300
      autoscaling_scale_out_adjustment     = 2
      autoscaling_scale_out_cooldown       = 60

      # Scale back in when cpu < 50% for 3 of 5 datapoints (defaults, tunable per app here)
      autoscaling_low_threshold           = 50
      autoscaling_low_datapoints_to_alarm = 3
      autoscaling_low_evaluation_periods  = 5
      autoscaling_low_period              = 600
      autoscaling_scale_in_adjustment     = 1
      autoscaling_scale_in_cooldown       = 60

      ingress_rules = [
        { cidr = "0.0.0.0/0", from_port = 80, to_port = 80, protocol = "tcp", description = "public web" },
      ]
    }

    # Internal app: larger task, scales 1..3.
    app2 = {
      image_prefix   = "super-app2"
      container_port = 80

      task_cpu    = 512
      task_memory = 1024

      desired_count = 1
      min_count     = 1
      max_count     = 3

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
