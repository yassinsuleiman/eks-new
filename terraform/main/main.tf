locals {
  # Single source of truth for the EKS cluster name, shared by the VPC subnet
  # tags (kubernetes.io/cluster/<name>) and the future EKS module.
  cluster_name = "${var.project_name}-${var.environment}"
}

module "vpc" {
  source = "../modules/vpc"

  project_name     = var.project_name
  environment      = var.environment
  vpc_cidr         = var.vpc_cidr
  az_count         = var.az_count
  eks_cluster_name = local.cluster_name
}
