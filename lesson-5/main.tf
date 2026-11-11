provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "neoversity-lesson-5"
      ManagedBy = "terraform"
      Owner     = "fedorstoiets"
    }
  }
}

variable "aws_region" {
  description = "AWS region for the tutorial deployment"
  type        = string
  default     = "us-east-2"
}

variable "bucket_name" {
  description = "Globally unique bucket name; e.g. fedorstoiets-neoversity-tfstate-123456789012"
  type        = string
}

variable "table_name" {
  description = "Name of DynamoDB state lock table"
  type        = string
  default     = "terraform-locks"

  validation {
    condition     = var.table_name == "terraform-locks"
    error_message = "This assignment backend.tf uses the table named terraform-locks."
  }
}

variable "nat_gateway_enabled" {
  description = "Whether to create a NAT gateway (billable); must be true to meet assignment requirements"
  type        = bool
  default     = true
}

module "s3_backend" {
  source      = "./modules/s3-backend"
  bucket_name = var.bucket_name
  table_name  = var.table_name
}

module "vpc" {
  source              = "./modules/vpc"
  vpc_cidr_block      = "10.0.0.0/16"
  public_subnets      = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  availability_zones  = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  vpc_name            = "lesson-5-vpc"
  nat_gateway_enabled = var.nat_gateway_enabled
}

module "ecr" {
  source       = "./modules/ecr"
  ecr_name     = "lesson-5-ecr"
  scan_on_push = true
}
