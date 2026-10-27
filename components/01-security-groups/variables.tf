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

variable "vpc_id" {
  description = "Optional override; empty reads vpc_id from 00-network state automatically."
  type        = string
  default     = ""
}
variable "app_port" {
  description = "Must match the confirmed application/container port."
  type        = number
  default     = 8080
}

variable "admin_ssh_cidr" {
  description = "Administrator public IPv4 CIDR allowed to SSH to staging, e.g. 203.0.113.10/32. Never use 0.0.0.0/0."
  type        = string
  validation {
    condition     = can(cidrhost(var.admin_ssh_cidr, 0)) && var.admin_ssh_cidr != "0.0.0.0/0"
    error_message = "Set a valid restricted administrator CIDR, not 0.0.0.0/0."
  }
}
