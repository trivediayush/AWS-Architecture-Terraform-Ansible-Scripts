# Placement: spread tasks across AZs first, then across container instances.
# NOTE: spread is a best-effort strategy, not a guarantee - with desired_count=1
# per service there is exactly one task per service to place; if a host fails
# ECS can only reschedule where capacity and placement rules allow. See README.

resource "aws_ecs_service" "frontend" {
  name            = "${var.project_name}-frontend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.asg.name
    weight            = 1
  }

  network_configuration {
    subnets          = aws_subnet.app[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "frontend"
    container_port   = 80
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "instanceId"
  }

  depends_on = [aws_lb_listener.http]
}

resource "aws_ecs_service" "api" {
  name            = "${var.project_name}-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.asg.name
    weight            = 1
  }

  network_configuration {
    subnets          = aws_subnet.app[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api"
    container_port   = 5678
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "instanceId"
  }

  depends_on = [aws_lb_listener.http]
}

resource "aws_ecs_service" "bl" {
  name            = "${var.project_name}-bl"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.bl.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.asg.name
    weight            = 1
  }

  network_configuration {
    subnets          = aws_subnet.app[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.bl.arn
    container_name   = "bl"
    container_port   = 5679
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "instanceId"
  }

  depends_on = [aws_lb_listener.http]
}

resource "aws_ecs_service" "mqtt" {
  name            = "${var.project_name}-mqtt"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.mqtt.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.asg.name
    weight            = 1
  }

  network_configuration {
    subnets          = aws_subnet.app[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.mqtt_ws.arn
    container_name   = "mqtt"
    container_port   = 9001
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "instanceId"
  }

  depends_on = [aws_lb_listener.http]
}
