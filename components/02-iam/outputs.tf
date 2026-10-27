output "staging_instance_profile_name" { value = aws_iam_instance_profile.staging.name }
output "ecs_instance_profile_name" { value = aws_iam_instance_profile.ecs.name }
output "ecs_task_execution_role_arn" { value = aws_iam_role.ecs_task_execution.arn }
output "ecs_task_role_arn" { value = aws_iam_role.ecs_task.arn }
output "staging_role_arn" { value = aws_iam_role.staging_ec2.arn }
