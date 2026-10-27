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
  default     = "production"
}

# --- s3 ---

variable "bucket_name" {
  description = "Globally unique production bucket name; set explicitly."
  type        = string
}

# --- rds ---

variable "db_identifier" {
  type    = string
  default = "sunroof-postgres"
}
variable "db_name" {
  description = "Initial database only; staging/prod logical DBs/users are created separately after approval (see README)."
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

# --- ecs capacity ---

variable "key_pair_name" {
  description = "Existing EC2 key pair name for administrative SSH when network access is available (e.g. VPN/bastion)."
  type        = string
  default     = "sunroof-key"
}
variable "ecs_instance_type" {
  description = "Instance type for ECS capacity nodes — architecture must match ecs_ami_id."
  type        = string
  default     = "c6g.xlarge"
}
variable "ecs_ami_id" {
  description = "AMI for ECS capacity nodes. Default: Ubuntu Server 26.04 LTS arm64. Plain (non-ECS-optimized) images get the agent via user_data."
  type        = string
  default     = "ami-01027cdb5f7b38e21"
}
variable "ecs_root_volume_size_gb" {
  type    = number
  default = 100
}
variable "ecs_desired_capacity" {
  type    = number
  default = 2
}
variable "ecs_min_size" {
  type    = number
  default = 2
}
variable "ecs_max_size" {
  type    = number
  default = 2
}
variable "ecs_cluster_name" {
  type    = string
  default = "sunroof-production"
}

# --- alb ---

variable "load_balancer_name" {
  type    = string
  default = "sunroof-production"
}
variable "target_port" {
  description = "Confirm with app owner; must match app_port and the ECS SG ingress."
  type        = number
  default     = 8080
}
variable "target_type" {
  description = "ip = ECS awsvpc tasks register directly; instance = bridge/host network mode."
  type        = string
  default     = "ip"
}
variable "health_check_path" {
  description = "App health endpoint; must return 2xx/3xx."
  type        = string
  default     = "/"
}
variable "certificate_arn" {
  description = "ARN of approved non-ACM IAM server certificate. Empty = HTTP-only forward listener (testing only)."
  type        = string
  default     = ""
}
variable "enable_alb_deletion_protection" {
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

# --- ecs service ---

variable "image_uri" {
  description = "Full image URI with tag (ECR or Docker Hub). Immutable tags — every deploy needs a new tag."
  type        = string
}
variable "app_port" {
  description = "Container port; must match the ALB target group port and ECS security group ingress."
  type        = number
  default     = 8080
}
variable "task_cpu" {
  description = "Task-level CPU units (1024 = 1 vCPU). Task + all containers must fit one capacity node."
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
  description = "Map of ENV name -> Secrets Manager secret ARN (or ARN:json-key::). The same ARNs get read access via task_secret_arns."
  type        = map(string)
  default     = {}
}
variable "task_secret_arns" {
  description = "Secrets Manager ARNs the task/execution roles may read. Must cover every ARN in container_secrets."
  type        = list(string)
  default     = []
}

# --- alarms ---

variable "log_retention_days" {
  type    = number
  default = 30
}
