output "db_endpoint" { value = aws_db_instance.this.address }
output "db_port" { value = aws_db_instance.this.port }
output "db_identifier" { value = aws_db_instance.this.identifier }
output "master_secret_arn" {
  value     = aws_db_instance.this.master_user_secret[0].secret_arn
  sensitive = true
}
output "alb_arn" { value = aws_lb.this.arn }
output "alb_dns_name" { value = aws_lb.this.dns_name }
output "https_listener_created" { value = var.certificate_arn != "" }
output "target_group_arn" { value = aws_lb_target_group.app.arn }
output "ecs_cluster_name" { value = aws_ecs_cluster.this.name }
output "service_name" { value = aws_ecs_service.app.name }
output "bucket_name" { value = aws_s3_bucket.production.id }
output "bucket_arn" { value = aws_s3_bucket.production.arn }
output "ecs_log_group_name" { value = aws_cloudwatch_log_group.ecs.name }
