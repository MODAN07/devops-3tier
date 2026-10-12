variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "project" {
  type    = string
  default = "devops3tier"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "github_org" {
  description = "GitHub username or organisation that owns the repo, exactly as it appears in the URL"
  type        = string
}

variable "github_repo" {
  description = "Repository name, e.g. devops-3tier"
  type        = string
}
