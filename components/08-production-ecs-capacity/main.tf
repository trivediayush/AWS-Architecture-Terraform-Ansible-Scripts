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
  count   = var.ecs_instance_profile_name == "" ? 1 : 0
  backend = "local"
  config  = { path = "${path.module}/../02-iam/terraform.tfstate" }
}

locals {
  private_subnet_ids        = length(var.private_subnet_ids) > 0 ? var.private_subnet_ids : data.terraform_remote_state.network[0].outputs.app_subnet_ids
  ecs_security_group_id     = var.ecs_security_group_id != "" ? var.ecs_security_group_id : data.terraform_remote_state.security[0].outputs.ecs_security_group_id
  ecs_instance_profile_name = var.ecs_instance_profile_name != "" ? var.ecs_instance_profile_name : data.terraform_remote_state.iam[0].outputs.ecs_instance_profile_name
}

resource "aws_ecs_cluster" "this" {
  name = var.ecs_cluster_name
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  tags = { Environment = "production" }
}

# Latest ECS-optimized Amazon Linux 2023 ARM64 AMI via EC2 API (no SSM).
data "aws_ami" "ecs_optimized_arm64" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-ecs-hvm-*-arm64-ebs"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_launch_template" "this" {
  name_prefix            = "${var.project_name}-ecs-"
  image_id               = data.aws_ami.ecs_optimized_arm64.id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  vpc_security_group_ids = [local.ecs_security_group_id]
  iam_instance_profile { name = local.ecs_instance_profile_name }
  update_default_version = true
  user_data = base64encode(<<-EOT
    #!/bin/bash
    set -euo pipefail
    echo ECS_CLUSTER=${aws_ecs_cluster.this.name} >> /etc/ecs/ecs.config
    echo ECS_ENABLE_CONTAINER_METADATA=true >> /etc/ecs/ecs.config
    EOT
  )
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_type           = "gp3"
      volume_size           = var.root_volume_size_gb
      encrypted             = true
      delete_on_termination = true
    }
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.project_name}-production-ecs-node", Environment = "production" }
  }
}

resource "aws_autoscaling_group" "this" {
  name                      = "${var.project_name}-production-ecs-asg"
  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.desired_capacity
  vpc_zone_identifier       = local.private_subnet_ids
  health_check_type         = "EC2"
  health_check_grace_period = 300
  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }
  tag {
    key                 = "Name"
    value               = "${var.project_name}-production-ecs-node"
    propagate_at_launch = true
  }
  tag {
    key                 = "Environment"
    value               = "production"
    propagate_at_launch = true
  }
}

resource "aws_ecs_capacity_provider" "this" {
  name = "${var.project_name}-production-ec2-capacity"
  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.this.arn
    managed_scaling {
      status          = "DISABLED"
      target_capacity = 100
    }
    managed_termination_protection = "DISABLED"
  }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = [aws_ecs_capacity_provider.this.name]
  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.this.name
    weight            = 1
  }
}
