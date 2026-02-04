terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.30.0"
    }
  }
  backend "s3" {
    bucket        = "terraform-up-and-running-state-phijo"
    key           = "stage/data-stores/mysql/terraform.tfstate"
    region        = "ap-south-1"
    use_lockfile  = true
    encrypt       = true
  }
}
provider "aws" {
  region = "ap-south-1"
}

resource "aws_db_instance" "db" {
  identifier_prefix   = "terraform-up-and-running"
  engine              = "mysql"
  allocated_storage   = 10
  instance_class      = "db.t3.micro"
  skip_final_snapshot = true
  db_name             = "example_db"
  username            = var.db_username
  password            = var.db_password
}