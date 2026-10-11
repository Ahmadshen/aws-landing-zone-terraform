terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.68"
    }
  }

  # backend "s3" {
  #   bucket       = "<state-bucket-in-management-account>"
  #   key          = "landing-zone/terraform.tfstate"
  #   region       = "us-east-1"
  #   use_lockfile = true
  # }
}

# Management account (credentials from your SSO session or the CI OIDC role).
provider "aws" {
  region = var.home_region
  default_tags {
    tags = local.tags
  }
}

# Log archive account, reached through the role AWS Organizations creates in every member account.
provider "aws" {
  alias  = "log_archive"
  region = var.home_region
  assume_role {
    role_arn = "arn:aws:iam::${var.log_archive_account_id}:role/OrganizationAccountAccessRole"
  }
  default_tags {
    tags = local.tags
  }
}
