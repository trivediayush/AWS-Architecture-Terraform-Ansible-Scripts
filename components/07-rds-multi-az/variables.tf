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

variable "database_subnet_ids" {
  description = "Optional override; empty reads database_subnet_ids from 00-network state."
  type        = list(string)
  default     = []
}
variable "rds_security_group_id" {
  description = "Optional override; empty reads rds_security_group_id from 01-security-groups state."
  type        = string
  default     = ""
}
variable "db_identifier" {
  type    = string
  default = "sunroof-postgres"
}
variable "db_name" {
  description = "Initial database only; staging/prod logical DBs/users are created separately by Ansible after approval."
  type        = string
  default     = "staging_app"
}
variable "master_username" {
  type = string
}
variable "instance_class" {
  description = "Must be confirmed against app requirements and the selected estimate."
  type        = string
}
variable "engine_version" {
  description = "Must be confirmed for application compatibility."
  type        = string
}
variable "allocated_storage_gb" {
  type    = number
  default = 100
}
variable "max_allocated_storage_gb" {
  description = "Upper bound for RDS storage autoscaling; prevents runaway growth."
  type        = number
  default     = 200
}
variable "apply_immediately" {
  description = "false = changes apply in the maintenance window (production-safe)."
  type        = bool
  default     = false
}
variable "backup_retention_days" {
  type    = number
  default = 7
}
variable "final_snapshot_identifier" {
  description = "Unique identifier for final snapshot on destroy; required for safe destruction."
  type        = string
}
variable "deletion_protection" {
  type    = bool
  default = true
}
