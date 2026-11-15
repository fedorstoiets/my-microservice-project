output "repository_url" {
  description = "Full ECR repository URI"
  value       = aws_ecr_repository.main.repository_url
}

output "tag_mutability" { value = aws_ecr_repository.main.image_tag_mutability }
