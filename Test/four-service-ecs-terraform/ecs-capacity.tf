# Latest ECS-optimized Amazon Linux 2023 AMI, arm64 variant (matches the
# Graviton c6g.xlarge instance type). Resolved at plan time by querying AMIs
# published under the "amazon" owner - no hardcoded AMI IDs, no SSM dependency.
data "aws_ami" "ecs" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-ecs-hvm-*-arm64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_launch_template" "ecs" {
  name_prefix   = "${var.project_name}-ecs-"
  image_id      = data.aws_ami.ecs.id
  instance_type = var.instance_type
  key_name      = var.key_pair_name

  iam_instance_profile {
    arn = aws_iam_instance_profile.ecs_instance.arn
  }

  # IMDSv2 required; hop limit 2 so processes inside containers can still
  # reach the instance metadata service (token response TTL would otherwise
  # be consumed by the container network hop).
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  monitoring {
    enabled = false
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.ecs_hosts.id]
    delete_on_termination       = true
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo "ECS_CLUSTER=${aws_ecs_cluster.main.name}" >> /etc/ecs/ecs.config
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.project_name}-ecs-host" }
  }
}

resource "aws_autoscaling_group" "ecs" {
  name                = "${var.project_name}-ecs-asg"
  min_size            = 2
  desired_capacity    = 2
  max_size            = 2
  vpc_zone_identifier = aws_subnet.app[*].id

  # Container instances only run ECS tasks; the ASG replaces on EC2 failure.
  health_check_type         = "EC2"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  # The ECS capacity provider manages lifecycle; let it handle termination.
  protect_from_scale_in = false

  tag {
    key                 = "Name"
    value               = "${var.project_name}-ecs-host"
    propagate_at_launch = true
  }

  # Required tag so the ECS capacity provider recognises ASG-managed instances.
  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

resource "aws_ecs_capacity_provider" "asg" {
  name = "${var.project_name}-asg-cp"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs.arn
    managed_termination_protection = "DISABLED"

    # Graceful task draining before instance termination (scale-in/replacement).
    managed_draining = "ENABLED"

    managed_scaling {
      status                    = "ENABLED"
      target_capacity           = 100
      minimum_scaling_step_size = 1
      maximum_scaling_step_size = 2
    }
  }
}
