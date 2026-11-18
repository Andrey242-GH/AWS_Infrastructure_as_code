variable "aws_region" {
  description = "AWS region for the ECR repository"
  type        = string
  default     = "us-east-1"
}

variable "repository_name" {
  description = "ECR repository name"
  type        = string
  default     = "my-php-app"
}

variable "image_tag_mutability" {
  description = "MUTABLE or IMMUTABLE"
  type        = string
  default     = "MUTABLE"
}

variable "force_delete" {
  description = "Allow terraform destroy to delete the repo even if it contains images"
  type        = bool
  default     = false
}

variable "max_image_count" {
  description = "Number of images to keep"
  type        = number
  default     = 10
}
