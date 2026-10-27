variable "aws_region" {
  description = "Approved AWS region."
  type        = string
}

variable "project_name" {
  description = "Short project tag prefix."
  type        = string
  default     = "sunroof"
}

variable "state_bucket_name" {
  description = "Globally unique bucket for Terraform state of all components."
  type        = string
}
