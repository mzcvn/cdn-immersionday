terraform {
  required_version = ">= 1.4.5"
  backend "s3" {
    bucket = "hungran20230903"
    key    = "tfstate/terraform.tfstate"
    region = "us-east-1"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.12.0"
    }
  }
}