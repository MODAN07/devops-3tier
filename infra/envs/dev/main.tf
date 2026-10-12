terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state in the bucket created by infra/bootstrap.
  # use_lockfile = native S3 locking (Terraform 1.10+), so no DynamoDB table is needed.
  # The bucket name can't use variables here, so replace <ACCOUNT_ID> with your 12-digit AWS account ID.
  backend "s3" {
    bucket       = "devops3tier-tfstate-716403253120"
    key          = "envs/dev/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region

  # Every resource gets these tags automatically. Useful for cost tracking and for finding orphans after a failed destroy.
  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name         = "${var.project}-${var.environment}"
  cluster_name = "${local.name}-eks"
  azs          = slice(data.aws_availability_zones.available.names, 0, 2)
}

module "vpc" {
  source = "../../modules/vpc"

  name         = local.name
  cidr         = var.vpc_cidr
  azs          = local.azs
  cluster_name = local.cluster_name

  single_nat_gateway = true
}

module "ecr" {
  source = "../../modules/ecr"

  name         = local.name
  repositories = ["frontend", "api"]
}

module "github_oidc" {
  source = "../../modules/github-oidc"

  name = local.name

  # Only workflows running on the main branch of THIS repo can assume the push role.
  ecr_push_subjects   = ["repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main"]
  ecr_repository_arns = module.ecr.repository_arns
}