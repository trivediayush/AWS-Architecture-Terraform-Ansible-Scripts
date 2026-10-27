output "vpc_id" { value = aws_vpc.this.id }
output "public_subnet_ids" { value = aws_subnet.public[*].id }
output "app_subnet_ids" { value = aws_subnet.app[*].id }
output "database_subnet_ids" { value = aws_subnet.database[*].id }
output "availability_zones" { value = var.availability_zones }
output "nat_gateway_ids" { value = aws_nat_gateway.this[*].id }

output "alb_security_group_id" { value = aws_security_group.alb.id }
output "staging_security_group_id" { value = aws_security_group.staging.id }
output "ecs_security_group_id" { value = aws_security_group.ecs.id }
output "rds_security_group_id" { value = aws_security_group.rds.id }

output "staging_instance_profile_name" { value = aws_iam_instance_profile.staging.name }
output "staging_role_name" { value = aws_iam_role.staging_ec2.name }
output "ecs_instance_profile_name" { value = aws_iam_instance_profile.ecs.name }
output "ecs_task_execution_role_arn" { value = aws_iam_role.ecs_task_execution.arn }
output "ecs_task_execution_role_name" { value = aws_iam_role.ecs_task_execution.name }
output "ecs_task_role_arn" { value = aws_iam_role.ecs_task.arn }
output "ecs_task_role_name" { value = aws_iam_role.ecs_task.name }

output "repository_url" { value = aws_ecr_repository.shared.repository_url }
output "repository_arn" { value = aws_ecr_repository.shared.arn }

output "alarm_topic_arn" { value = length(aws_sns_topic.alarms) > 0 ? aws_sns_topic.alarms[0].arn : "" }
