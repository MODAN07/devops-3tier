variable "name" {
  description = "Prefix for resource names, e.g. devops3tier-dev"
  type        = string
}

variable "cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones to spread subnets across (2 is enough for this project)"
  type        = list(string)
}

variable "cluster_name" {
  description = "EKS cluster name. Used only to tag subnets so the AWS load balancer controller can find them."
  type        = string
}

variable "single_nat_gateway" {
  description = "true = one shared NAT gateway (cheap, lab use). false = one per AZ (resilient, ~3x the cost)."
  type        = bool
  default     = true
}

variable "flow_log_retention_days" {
  description = "How long VPC flow logs are kept in CloudWatch"
  type        = number
  default     = 14
}
