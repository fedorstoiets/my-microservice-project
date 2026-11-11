variable "bucket_name" {
  description = "Globally unique S3 bucket name"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Use a valid globally unique lowercase S3 bucket name (3–63 characters)."
  }
}

variable "table_name" {
  description = "DynamoDB table name for legacy Terraform state locking"
  type        = string
}
