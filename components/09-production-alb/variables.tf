variable "aws_region" {
  description = "Approved AWS region."
  type        = string
}
variable "project_name" {
  description = "Short project tag prefix."
  type        = string
  default     = "sunroof"
}
variable "environment" {
  description = "Environment tag."
  type        = string
  default     = "shared"
}

variable "public_subnet_ids" {
  description = "Optional override; empty reads public_subnet_ids from 00-network state."
  type        = list(string)
  default     = []
}
variable "alb_security_group_id" {
  description = "Optional override; empty reads alb_security_group_id from 01-security-groups state."
  type        = string
  default     = ""
}
variable "target_port" {
  description = "Confirm with app owner; placeholder default only."
  type        = number
  default     = 8080
}
variable "target_type" {
  description = "ip = ECS awsvpc tasks register directly (used by 11-production-ecs-service); instance = bridge/host network mode."
  type        = string
  default     = "ip"
}
variable "health_check_path" {
  description = "App health endpoint; must return 2xx/3xx."
  type        = string
  default     = "/"
}
variable "certificate_arn" {
  description = "ARN of approved non-ACM IAM server certificate. Empty means no listener is created."
  type        = string
  default     = ""
}
variable "load_balancer_name" {
  type    = string
  default = "sunroof-production"
}
variable "enable_deletion_protection" {
  description = "false keeps the ALB easy to destroy; enable only for a hardened production cutover."
  type        = bool
  default     = false
}
variable "enable_access_logs" {
  type    = bool
  default = true
}
variable "access_logs_bucket_name" {
  description = "Globally unique bucket for ALB access logs; required when enable_access_logs = true."
  type        = string
  default     = ""
}
variable "access_logs_retention_days" {
  type    = number
  default = 90
}
variable "access_logs_force_destroy" {
  description = "true lets terraform destroy delete the log bucket even when non-empty."
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "Optional override; empty reads vpc_id from 00-network state."
  type        = string
  default     = ""
}
