variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Name prefix applied to all resources."
  type        = string
  default     = "four-svc-test"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name may only contain lowercase letters, numbers and hyphens."
  }
}

variable "environment" {
  description = "Environment label used in tags and names."
  type        = string
  default     = "test"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.40.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDRs for the two public subnets (one per AZ)."
  type        = list(string)
  default     = ["10.40.1.0/24", "10.40.2.0/24"]
}

variable "app_subnet_cidrs" {
  description = "CIDRs for the two private application subnets (one per AZ)."
  type        = list(string)
  default     = ["10.40.11.0/24", "10.40.12.0/24"]
}

variable "db_subnet_cidrs" {
  description = "CIDRs for the two private database subnets (one per AZ)."
  type        = list(string)
  default     = ["10.40.21.0/24", "10.40.22.0/24"]
}

variable "allowed_admin_cidr" {
  description = "CIDR allowed to reach the ALB on port 80. Set this to your public IP in /32 form (for example \"203.0.113.10/32\"). No default on purpose - internet-wide access must be a deliberate choice."
  type        = string

  validation {
    condition     = can(cidrhost(var.allowed_admin_cidr, 0))
    error_message = "allowed_admin_cidr must be a valid IPv4 CIDR block, e.g. \"203.0.113.10/32\"."
  }
}

variable "instance_type" {
  description = "EC2 instance type for ECS container hosts. Must be an ARM64 (Graviton) type to match the ECS-optimized arm64 AMI and the arm64 container images."
  type        = string
  default     = "c6g.xlarge"
}

variable "key_pair_name" {
  description = "Existing EC2 key pair to attach to the container hosts (for SSH from inside the VPC). Hosts are private; see README for how to reach them."
  type        = string
  default     = "sunroof-key"
}

variable "container_insights" {
  description = "Enable CloudWatch Container Insights on the cluster. Adds CloudWatch cost; useful for learning, off by default."
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "Retention for the ECS CloudWatch log group."
  type        = number
  default     = 7
}

# ---- Sample images (all published as multi-arch manifests including linux/arm64) ----

variable "frontend_image" {
  description = "Container image for the frontend service. Official nginx; arm64 supported."
  type        = string
  default     = "nginx:1.29.8-alpine"
}

variable "api_image" {
  description = "Container image for the API sample service (echo server). ealen/echo-server is multi-arch including arm64."
  type        = string
  default     = "ealen/echo-server:0.9.2"
}

variable "bl_image" {
  description = "Container image for the business-logic sample service (echo server, different port and env)."
  type        = string
  default     = "ealen/echo-server:0.9.2"
}

variable "mqtt_image" {
  description = "Container image for the MQTT broker. eclipse-mosquitto is multi-arch including arm64."
  type        = string
  default     = "eclipse-mosquitto:2.0.22"
}

# ---- RDS ----

variable "db_engine" {
  description = "RDS engine: postgres or mysql."
  type        = string
  default     = "postgres"

  validation {
    condition     = contains(["postgres", "mysql"], var.db_engine)
    error_message = "db_engine must be \"postgres\" or \"mysql\"."
  }
}

variable "db_engine_version" {
  description = "Engine version. Empty string picks a sensible default per engine (postgres 16, mysql 8.0). Verify availability in your region."
  type        = string
  default     = ""
}

variable "db_instance_class" {
  description = "RDS instance class. db.t4g.micro is the smallest Multi-AZ-capable Graviton class; verify price/availability in ap-south-1."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_name" {
  description = "Initial database name."
  type        = string
  default     = "appdb"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.db_name))
    error_message = "db_name must start with a letter and contain only letters, digits and underscores."
  }
}

variable "db_username" {
  description = "RDS master username. Note: \"admin\" is a reserved word on RDS."
  type        = string
  default     = "appuser"
}

variable "db_password" {
  description = "RDS master password. Sensitive - supply via TF_VAR_db_password, never commit it. RDS forbids '/', '@', '\"' and spaces."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[^/@\"\\s]{8,128}$", var.db_password))
    error_message = "db_password must be 8-128 printable ASCII chars and may not contain '/', '@', '\"' or spaces."
  }
}

variable "s3_bucket_name" {
  description = "S3 bucket name. Must be globally unique. Empty string auto-generates <project>-app-<account-id>."
  type        = string
  default     = ""
}
