terraform {
  required_version = ">= 1.14.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
  backend "s3" {
    key          = "lesson-7/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
