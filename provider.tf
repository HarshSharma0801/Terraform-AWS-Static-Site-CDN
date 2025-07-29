terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1" 
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1" # For ACM Certificate used by CloudFront
}
