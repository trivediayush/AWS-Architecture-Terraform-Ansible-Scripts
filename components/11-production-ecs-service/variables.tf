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

variable "ecs_cluster_name" {
  description = "Optional override; empty reads ecs_cluster_name from 08-production-ecs-capacity state."
  type        = string
  default     = ""
}
variable "private_subnet_ids" {
  description = "Optional override; empty reads app_subnet_ids from 00-network state."
  type        = list(string)
  default     = []
}
variable "ecs_security_group_id" {
  description = "Optional override; empty reads ecs_security_group_id from 01-security-groups state."
  type        = string
  default     = ""
}
variable "target_group_arn" {
  description = "Optional override; empty reads target_group_arn from 09-production-alb state."
  type        = string
  default     = ""
}
variable "task_execution_role_arn" {
  description = "Optional override; empty reads ecs_task_execution_role_arn from 02-iam state."
  type        = string
  default     = ""
}
variable "task_role_arn" {
  description = "Optional override; empty reads ecs_task_role_arn from 02-iam state."
  type        = string
  default     = ""
}
variable "log_group_name" {
  description = "Optional override; empty reads ecs_log_group_name from 10-cloudwatch state."
  type        = string
  default     = ""
}

variable "image_uri" {
  description = "Full ECR image URI with tag, e.g. <acct>.dkr.ecr.<region>.amazonaws.com/sunroof/shared-app:v1. Immutable tags — every deploy needs a new tag."
  type        = string
}
variable "app_port" {
  description = "Container port; must match the ALB target group port and ECS security group ingress."
  type        = number
  default     = 8080
}
variable "task_cpu" {
  description = "Task-level CPU units (1024 = 1 vCPU). Task + all containers must fit one c6g.xlarge (4096 units)."
  type        = number
  default     = 1024
}
variable "task_memory" {
  description = "Task-level memory MiB. Must fit within node memory after agent/OS overhead."
  type        = number
  default     = 2048
}
variable "desired_count" {
  type    = number
  default = 2
}
variable "container_environment" {
  description = "Plain env vars for the container."
  type        = map(string)
  default     = {}
}
variable "container_secrets" {
  description = "Map of ENV name -> Secrets Manager secret ARN (or ARN:json-key::). ARNs must also be listed in 02-iam task_secret_arns."
  type        = map(string)
  default     = {}
}
