output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer."
  value       = aws_lb.app.dns_name
}

output "frontend_url" {
  description = "Frontend (nginx) root endpoint."
  value       = "http://${aws_lb.app.dns_name}/"
}

output "api_url" {
  description = "API sample endpoint."
  value       = "http://${aws_lb.app.dns_name}/api/"
}

output "bl_url" {
  description = "Business-logic sample endpoint."
  value       = "http://${aws_lb.app.dns_name}/bl/"
}

output "mqtt_ws_url" {
  description = "MQTT-over-WebSockets endpoint (use with a WS-capable MQTT client such as MQTT.js or MQTT Explorer). Native TCP/1883 is NOT reachable through the ALB."
  value       = "ws://${aws_lb.app.dns_name}/mqtt"
}

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_names" {
  description = "Names of the four ECS services."
  value = [
    aws_ecs_service.frontend.name,
    aws_ecs_service.api.name,
    aws_ecs_service.bl.name,
    aws_ecs_service.mqtt.name,
  ]
}

output "ecr_repository_urls" {
  description = "ECR repository URLs per service."
  value       = { for k, r in aws_ecr_repository.services : k => r.repository_url }
}

output "rds_endpoint" {
  description = "RDS endpoint (hostname:port). Internal only - not reachable from the internet."
  value       = aws_db_instance.main.endpoint
}

output "rds_engine" {
  description = "RDS engine and port in use."
  value       = "${var.db_engine}:${local.db_port}"
}

output "s3_bucket_name" {
  description = "Private S3 bucket name."
  value       = aws_s3_bucket.app.bucket
}

output "nat_gateway_public_ip" {
  description = "Public IP of the single NAT Gateway (outbound only)."
  value       = aws_eip.nat.public_ip
}

output "log_group_name" {
  description = "CloudWatch log group shared by all four services."
  value       = aws_cloudwatch_log_group.ecs.name
}
