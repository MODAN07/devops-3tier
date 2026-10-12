output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "database_subnet_ids" {
  value = module.vpc.database_subnet_ids
}

output "cluster_name" {
  value = local.cluster_name
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "github_ecr_push_role_arn" {
  description = "Save as GitHub repo variable AWS_ECR_PUSH_ROLE_ARN"
  value       = module.github_oidc.ecr_push_role_arn
}