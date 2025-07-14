terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "newrelic-tracing"
}

variable "new_relic_license_key" {
  description = "New Relic License Key"
  type        = string
  sensitive   = true
}

locals {
  common_tags = {
    Project = var.project_name
    Environment = "demo"
  }
}