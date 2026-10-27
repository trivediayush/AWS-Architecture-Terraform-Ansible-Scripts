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

variable "staging_bucket_arn" {
  description = "Staging S3 bucket ARN from 04-staging-s3; empty = no S3 policy on staging role."
  type        = string
  default     = ""
}
variable "production_bucket_arn" {
  description = "Production S3 bucket ARN from 05-production-s3; empty = no S3 policy on ECS task role."
  type        = string
  default     = ""
}
variable "task_secret_arns" {
  description = "Secrets Manager ARNs the ECS tasks may read (e.g. RDS master_user_secret ARN from 07-rds-multi-az)."
  type        = list(string)
  default     = []
}
