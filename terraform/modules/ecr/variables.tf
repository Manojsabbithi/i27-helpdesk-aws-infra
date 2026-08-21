variable "repository_names" {
  description = "Names of ECR repositories"
  type        = set(string)
}

variable "max_image_count" {
  description = "Maximum number of images retained per repository"
  type        = number
  default     = 10
}
