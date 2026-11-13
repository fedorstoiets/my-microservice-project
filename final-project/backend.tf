terraform {
  required_version = ">= 1.14.0"
  required_providers {
    aws  = { source = "hashicorp/aws", version = "~> 6.0" }
    helm = { source = "hashicorp/helm", version = "~> 3.0" }
  }
  backend "s3" {
    key          = "final-project/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
