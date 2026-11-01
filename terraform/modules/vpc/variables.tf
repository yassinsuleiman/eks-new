variable "project_name" {
  description = "Project name used for consistent tagging and naming."
  type        = string
}

variable "environment" {
  description = "Environment name (development, production, etc.)."
  type        = string
}

variable "az_count" {
  description = "Number of Availability Zones to use (EKS needs at least 2)."
  type        = number
  default     = 3

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 4 && floor(var.az_count) == var.az_count
    error_message = "az_count must be a whole number between 2 and 4."
  }
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC. Must be a /16 to /19 so the subnet layout fits."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && can(regex("/(1[6-9])$", var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR with a prefix length between /16 and /19."
  }
}

variable "eks_cluster_name" {
  description = "EKS cluster name used for subnet tagging (for Kubernetes load balancers)."
  type        = string
}
