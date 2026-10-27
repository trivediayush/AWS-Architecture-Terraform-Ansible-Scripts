output "staging_log_group_name" { value = aws_cloudwatch_log_group.staging.name }
output "ecs_log_group_name" { value = aws_cloudwatch_log_group.ecs.name }
