output "ecr_push_role_arn" {
  description = "Put this in the GitHub repo variable AWS_ECR_PUSH_ROLE_ARN. A role ARN is not a secret."
  value       = aws_iam_role.ecr_push.arn
}

output "oidc_provider_arn" {
  value = data.aws_iam_openid_connect_provider.github.arn
}