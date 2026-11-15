terraform {
  required_version = ">= 1.14.0"
  required_providers { aws = { source = "hashicorp/aws", version = "~> 6.0" } }
  # Bootstrap uses LOCAL state until S3 is created and verified.
}
provider "aws" { region = var.aws_region }
variable "aws_region" {
  type    = string
  default = "us-east-2"
}
variable "bucket_name" { type = string }
variable "table_name" {
  type    = string
  default = null
}
module "s3_backend" {
  source      = "../modules/s3-backend"
  bucket_name = var.bucket_name
  table_name  = coalesce(var.table_name, "${var.bucket_name}-locks")
  kms_key_arn = aws_kms_key.backend.arn
}
output "state_bucket_url" { value = module.s3_backend.bucket_url }
output "table_name" { value = module.s3_backend.table_name }

resource "aws_kms_key" "backend" {
  description             = "Terraform state and lock encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  lifecycle { prevent_destroy = true }
}
variable "new_environment" {
  description = "Explicitly acknowledge this bootstrap is for a new bucket, not legacy lesson-5 resources."
  type        = bool
  default     = false
  validation {
    condition     = var.new_environment
    error_message = "Do not recreate existing backend resources. A new environment requires new_environment=true and a separately approved plan."
  }
}
