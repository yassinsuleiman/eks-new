terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

variable "project_name" {
  type    = string
  default = "eks"
}

variable "aws_region" {
  description = "AWS Region in which your Infrastructure will be deployed in"
  type        = string
  default     = "eu-west-2"
}

variable "state_bucket_name" {
  description = "S3 bucket for remote state; must match the backend block in ../main/versions.tf"
  type        = string
  default     = "eks-tfstate-yassin"
}

provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "state" {
  bucket = var.state_bucket_name

  tags = {
    Name    = "Terraform State"
    Project = "${var.project_name}-project"
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_ecr_repository" "main" {
  name                 = "${var.project_name}-repo"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = { Name = "${var.project_name}-repo" }
}

output "repo_url" {
  value = aws_ecr_repository.main.repository_url
}

output "state_bucket" {
  value       = aws_s3_bucket.state.id
  description = "S3 bucket name for terraform state"
}

output "region" {
  value       = var.aws_region
  description = "AWS region"
}