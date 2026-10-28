resource "aws_cloudwatch_log_group" "ecs" {
  name              = local.log_group_name
  retention_in_days = var.log_retention_days

  tags = { Name = "${var.project_name}-logs" }
}
