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

# --- network ---

variable "vpc_cidr" {
  type    = string
  default = "10.40.0.0/16"
}
variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.40.1.0/24", "10.40.2.0/24"]
}
variable "private_app_subnet_cidrs" {
  type    = list(string)
  default = ["10.40.11.0/24", "10.40.12.0/24"]
}
variable "database_subnet_cidrs" {
  type    = list(string)
  default = ["10.40.21.0/24", "10.40.22.0/24"]
}
variable "availability_zones" {
  description = "Exactly two approved AZ names in the selected region."
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}
variable "enable_nat_gateway" {
  description = "Required for private ECS hosts to reach ECR/ECS endpoints. Set false only if VPC endpoints or another approved egress replaces it."
  type        = bool
  default     = true
}
variable "single_nat_gateway" {
  description = "true = one NAT shared by both AZs (cheaper, cross-AZ dependency); false = one NAT per AZ."
  type        = bool
  default     = false
}

# --- security groups ---

variable "app_port" {
  description = "Must match the confirmed application/container port."
  type        = number
  default     = 8080
}

variable "admin_ssh_cidr" {
  description = "Administrator public IPv4 CIDR allowed to SSH to staging, e.g. 203.0.113.10/32. A bare IPv4 address is auto-treated as /32. Never use 0.0.0.0/0."
  type        = string
  validation {
    condition     = (can(cidrhost(var.admin_ssh_cidr, 0)) || can(cidrhost("${var.admin_ssh_cidr}/32", 0))) && !contains(["0.0.0.0/0", "0.0.0.0"], var.admin_ssh_cidr)
    error_message = "Set a valid restricted administrator CIDR or bare IPv4 address, not 0.0.0.0/0."
  }
}

# --- ecr ---

variable "repository_name" {
  type    = string
  default = "sunroof/shared-app"
}

# --- alarms ---

variable "alarm_email" {
  description = "Notification email for alarms; empty = alarms created without notifications. Must confirm the SNS subscription email."
  type        = string
  default     = ""
}
