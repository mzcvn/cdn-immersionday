provider "aws" {
  region = "ap-southeast-1"
}
provider "aws" {
  alias = "lambda_edge"
  region = "us-east-1"
}
