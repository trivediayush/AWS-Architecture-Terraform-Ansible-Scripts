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

variable "log_retention_days" {
  type    = number
  default = 30
}
variable "staging_instance_id" {
  type    = string
  default = ""
}
variable "rds_identifier" {
  type    = string
  default = ""
}
variable "alb_arn_suffix" {
  description = "ALB arn_suffix, e.g. app/sunroof-production/abc123."
  type        = string
  default     = ""
}
variable "target_group_arn_suffix" {
  description = "Target group arn_suffix, e.g. targetgroup/sunroof-prod-app/abc123."
  type        = string
  default     = ""
}
variable "alarm_email" {
  description = "Notification email for alarms; empty = alarms created without notifications. Must confirm the SNS subscription email."
  type        = string
  default     = ""
}
variable "ecs_cluster_name" {
  type    = string
  default = ""
}
variable "ecs_service_name" {
  type    = string
  default = ""
}
