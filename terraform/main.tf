terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # Replace with your S3 backend config before applying
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "gitlab-mcp/terraform.tfstate"
  #   region         = "ap-southeast-2"
  #   dynamodb_table = "terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "gitlab-mcp"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  name_prefix    = "gitlab-mcp-${var.environment}"
  account_id     = data.aws_caller_identity.current.account_id
  aws_region     = data.aws_region.current.name
  ecr_image_uri  = "${local.account_id}.dkr.ecr.${local.aws_region}.amazonaws.com/${local.name_prefix}:${var.image_tag}"
}
