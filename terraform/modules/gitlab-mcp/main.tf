terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  name_prefix = "${var.name}-${var.environment}"
  account_id  = data.aws_caller_identity.current.account_id
  aws_region  = data.aws_region.current.name
  image_uri   = "${aws_ecr_repository.this.repository_url}:${var.image_tag}"
}
