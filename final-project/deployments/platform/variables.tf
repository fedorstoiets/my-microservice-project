variable "aws_region" { type = string }
variable "state_bucket" { type = string }
variable "infra_state_key" {
  type    = string
  default = "goaldevops-v2/infra.tfstate"
  validation {
    condition     = startswith(var.infra_state_key, "goaldevops-v2/")
    error_message = "This root may consume only the separate v2 environment state, never legacy lesson state."
  }
}
variable "source_repo" {
  type    = string
  default = "https://github.com/fedorstoiets/my-microservice-project.git"
}
variable "gitops_repo" {
  type    = string
  default = "https://github.com/fedorstoiets/neoversity-django-gitops.git"
}
variable "ci_tools_image" {
  description = "Build ci/Dockerfile, push after approval, and supply the resulting immutable ECR digest."
  type        = string
  validation {
    condition     = can(regex("@sha256:[a-f0-9]{64}$", var.ci_tools_image))
    error_message = "CI tools image must be pinned to an actual verified digest."
  }
}
variable "kaniko_image" {
  type = string
  validation {
    condition     = can(regex("@sha256:[a-f0-9]{64}$", var.kaniko_image)) && !startswith(var.kaniko_image, "gcr.io/kaniko-project/")
    error_message = "Use a reviewed maintained builder digest from docs/evidence/image-pins.json; archived upstream images are not accepted for new rollout."
  }
}

variable "reviewed_gitops_base" {
  description = "Optional exact initial GitOps revision whose template replacement was separately reviewed."
  type        = string
  default     = ""
  validation {
    condition     = var.reviewed_gitops_base == "" || can(regex("^[a-f0-9]{40}$", var.reviewed_gitops_base))
    error_message = "Supply an actual reviewed full GitOps commit, not a branch name."
  }
}

variable "enable_application_sync" {
  description = "Enable only after explicit application/database deployment authorization; false during platform installation."
  type        = bool
  default     = false
}
variable "enable_database_bootstrap" {
  description = "One-time fresh database role bootstrap, separately authorized; turn off after verified initialization."
  type        = bool
  default     = false
  validation {
    condition     = !var.enable_database_bootstrap || var.enable_application_sync
    error_message = "Database bootstrap must be explicitly authorized together with application sync."
  }
}

variable "enable_application_pruning" {
  type    = bool
  default = false
}
