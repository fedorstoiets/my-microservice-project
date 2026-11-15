# Preserve provider default_tags from the source Terraform states during migration.
# These aliases are TEMPORARY continuity controls, not the final tagging strategy.
provider "aws" {
  region = var.aws_region
}

provider "aws" {
  alias  = "legacy5"
  region = var.aws_region
  default_tags {
    tags = {
      Project   = "neoversity-lesson-5"
      ManagedBy = "terraform"
      Owner     = "fedorstoiets"
    }
  }
}

provider "aws" {
  alias  = "legacy7"
  region = var.aws_region
  default_tags {
    tags = {
      Project   = "neoversity-lesson-7"
      Owner     = "fedorstoiets"
      ManagedBy = "terraform"
    }
  }
}
