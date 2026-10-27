# shortcut: reads sibling components' local state; switch backend/config to s3
# after remote-state migration.
data "terraform_remote_state" "network" {
  count   = length(var.private_subnet_ids) == 0 ? 1 : 0
  backend = "local"
  config  = { path = "${path.module}/../00-network/terraform.tfstate" }
}
data "terraform_remote_state" "security" {
  count   = var.ecs_security_group_id == "" ? 1 : 0
  backend = "local"
  config  = { path = "${path.module}/../01-security-groups/terraform.tfstate" }
}
data "terraform_remote_state" "iam" {
  count   = var.task_execution_role_arn == "" || var.task_role_arn == "" ? 1 : 0
  backend = "local"
  config  = { path = "${path.module}/../02-iam/terraform.tfstate" }
}
data "terraform_remote_state" "ecs" {
  count   = var.ecs_cluster_name == "" ? 1 : 0
  backend = "local"
  config  = { path = "${path.module}/../08-production-ecs-capacity/terraform.tfstate" }
}
data "terraform_remote_state" "alb" {
  count   = var.target_group_arn == "" ? 1 : 0
  backend = "local"
  config  = { path = "${path.module}/../09-production-alb/terraform.tfstate" }
}
data "terraform_remote_state" "cloudwatch" {
  count   = var.log_group_name == "" ? 1 : 0
  backend = "local"
  config  = { path = "${path.module}/../10-cloudwatch/terraform.tfstate" }
}

locals {
  private_subnet_ids      = length(var.private_subnet_ids) > 0 ? var.private_subnet_ids : data.terraform_remote_state.network[0].outputs.app_subnet_ids
  ecs_security_group_id   = var.ecs_security_group_id != "" ? var.ecs_security_group_id : data.terraform_remote_state.security[0].outputs.ecs_security_group_id
  task_execution_role_arn = var.task_execution_role_arn != "" ? var.task_execution_role_arn : data.terraform_remote_state.iam[0].outputs.ecs_task_execution_role_arn
  task_role_arn           = var.task_role_arn != "" ? var.task_role_arn : data.terraform_remote_state.iam[0].outputs.ecs_task_role_arn
  ecs_cluster_name        = var.ecs_cluster_name != "" ? var.ecs_cluster_name : data.terraform_remote_state.ecs[0].outputs.ecs_cluster_name
  target_group_arn        = var.target_group_arn != "" ? var.target_group_arn : data.terraform_remote_state.alb[0].outputs.target_group_arn
  log_group_name          = var.log_group_name != "" ? var.log_group_name : data.terraform_remote_state.cloudwatch[0].outputs.ecs_log_group_name
}

# Production ECS service + task definition. Apply only after the app image,
# port, CPU/memory, health endpoint and secrets are confirmed — the service
# will fail health checks if the image/listener values are placeholders.
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project_name}-production-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = local.task_execution_role_arn
  task_role_arn            = local.task_role_arn

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = var.image_uri
      essential = true
      portMappings = [
        { containerPort = var.app_port, hostPort = var.app_port, protocol = "tcp" }
      ]
      environment = [for k, v in var.container_environment : { name = k, value = v }]
      secrets     = [for k, v in var.container_secrets : { name = k, valueFrom = v }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = local.log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "app"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "app" {
  name            = "${var.project_name}-production-app"
  cluster         = local.ecs_cluster_name
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count

  network_configuration {
    subnets         = local.private_subnet_ids
    security_groups = [local.ecs_security_group_id]
  }

  load_balancer {
    target_group_arn = local.target_group_arn
    container_name   = "app"
    container_port   = var.app_port
  }

  health_check_grace_period_seconds = 60

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  tags = { Environment = "production" }
}
