output "repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.app.repository_url
}

output "registry" {
  description = "ECR registry host used for docker login"
  value       = split("/", aws_ecr_repository.app.repository_url)[0]
}

output "aws_region" {
  value = var.aws_region
}
