output "ecs_cluster_name" { value = aws_ecs_cluster.this.name }
output "ecs_cluster_arn" { value = aws_ecs_cluster.this.arn }
output "autoscaling_group_name" { value = aws_autoscaling_group.this.name }
output "launch_template_id" { value = aws_launch_template.this.id }
