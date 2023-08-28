terraform {
  required_version = " ~> 1.4.5"
  backend "s3" {
    bucket         = "cdn-tf-state"
    key            = "tfstate/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "cdn-tf-locks"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.12.0"
    }
  }
}