resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = var.container_insights ? "enabled" : "disabled"
  }

  tags = { Name = "${var.project_name}-cluster" }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = [aws_ecs_capacity_provider.asg.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.asg.name
    weight            = 1
    base              = 0
  }
}
