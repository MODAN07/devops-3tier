output "repository_urls" {
  description = "Map of short name => full repository URL (what docker push targets)"
  value       = { for k, r in aws_ecr_repository.this : k => r.repository_url }
}

output "repository_arns" {
  description = "Used to scope the CI role's push permission to exactly these repositories"
  value       = [for r in aws_ecr_repository.this : r.arn]
}