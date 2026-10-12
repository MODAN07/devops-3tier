variable "name" {
  description = "Prefix for the role name, e.g. devops3tier-dev"
  type        = string
}

variable "ecr_push_subjects" {
  description = <<-EOT
    GitHub OIDC 'sub' claims allowed to assume the ECR push role. Be exact, never use wildcards on the owner.
    Examples:
      repo:OWNER/REPO:ref:refs/heads/main      pushes from the main branch
      repo:OWNER/REPO:environment:dev          jobs that target a GitHub Environment named dev
  EOT
  type        = list(string)
}

variable "ecr_repository_arns" {
  description = "The only repositories the CI role may push to"
  type        = list(string)
}