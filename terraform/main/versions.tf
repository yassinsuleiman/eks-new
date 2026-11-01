terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket       = "eks-tfstate-yassin"
    key          = "eks-tfstate-yassin/eksproject.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }
}
