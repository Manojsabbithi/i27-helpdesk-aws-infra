variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-2"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "i27-helpdesk"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}
