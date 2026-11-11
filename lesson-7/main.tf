provider "aws" {
  region = var.aws_region
  default_tags {
    tags = { Project = "neoversity-lesson-7", Owner = "fedorstoiets", ManagedBy = "terraform" }
  }
}
variable "aws_region" {
  type    = string
  default = "us-east-2"
}
variable "cluster_name" {
  type    = string
  default = "neoversity-lesson-7"
}
variable "node_instance_type" {
  type    = string
  default = "t3.medium"
}

# Reuses the SAME VPC from lesson-5; never provisions a second VPC.
# The lesson-5 backend bucket and outputs must still exist.
data "terraform_remote_state" "lesson5" {
  backend = "s3"
  config = {
    bucket       = "fedorstoiets-neoversity-tfstate-${data.aws_caller_identity.current.account_id}"
    key          = "lesson-5/terraform.tfstate"
    region       = var.aws_region
    use_lockfile = true
  }
}
data "aws_caller_identity" "current" {}

module "eks" {
  source             = "./modules/eks"
  cluster_name       = var.cluster_name
  subnet_ids         = data.terraform_remote_state.lesson5.outputs.private_subnet_ids
  public_subnet_ids  = data.terraform_remote_state.lesson5.outputs.public_subnet_ids
  vpc_id             = data.terraform_remote_state.lesson5.outputs.vpc_id
  node_instance_type = var.node_instance_type
}

module "ecr" {
  source       = "./modules/ecr"
  ecr_name     = "lesson-7-django"
  scan_on_push = true
}

# The s3-backend/ and vpc/ modules from lesson-5 are included as
# documented reference source. NOT instantiated: lesson-5 owns them.
