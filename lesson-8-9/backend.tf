terraform {
  required_version = ">= 1.14.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
    helm = { source = "hashicorp/helm", version = "~> 3.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.30" }
  }
  backend "s3" {
    key          = "lesson-8-9/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
