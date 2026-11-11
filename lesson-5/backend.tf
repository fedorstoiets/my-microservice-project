terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # bucket and region are passed with -backend-config=backend.hcl.
  # The bucket/table must be created before using this backend.
  backend "s3" {
    key            = "lesson-5/terraform.tfstate"
    encrypt        = true
    dynamodb_table = "terraform-locks" # Legacy requirement of homework; deprecated in Terraform.
    use_lockfile   = true              # Current native S3 locking mechanism.
  }
}
