variable "name" {
  description = "Prefix for repository names, e.g. devops3tier-dev"
  type        = string
}

variable "repositories" {
  description = "One ECR repository is created per entry, named <name>/<entry>"
  type        = list(string)
}

variable "keep_last_images" {
  description = "Older images beyond this count are expired automatically (ECR storage is billed per GB)"
  type        = number
  default     = 10
}

variable "force_delete" {
  description = "true lets terraform destroy remove a repository that still contains images (lab convenience). Set false in production."
  type        = bool
  default     = true
}