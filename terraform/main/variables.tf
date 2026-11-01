variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-west-2"
}

variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "eks"
}

variable "environment" {
  description = "Deployment environment (e.g. dev, prod)"
  type        = string
  default     = "dev"
}
