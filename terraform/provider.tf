# PROVIDER
terraform {

  required_version = "~> 1.5.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.13"
    }
  }

  backend "s3" {
    bucket         = "app-notifier-tf-luiz"
    key            = "terraform.tfstate"
    dynamodb_table = "app-notifier-tf-luiz"
    region         = "us-east-1"
  }

}
