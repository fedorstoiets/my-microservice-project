variable "aws_region" {
  type    = string
  default = "us-east-2"
}
variable "cluster_name" {
  type    = string
  default = "neoversity-lesson-7"
}
variable "ecr_repository_name" {
  type    = string
  default = "lesson-7-django"
}
variable "github_source_repo" {
  type    = string
  default = "https://github.com/fedorstoiets/my-microservice-project.git"
}
variable "github_gitops_repo" {
  type    = string
  default = "https://github.com/fedorstoiets/neoversity-django-gitops.git"
}
variable "deploy_database" {
  type    = bool
  default = true
  validation {
    condition     = var.deploy_database
    error_message = "Keep deploy_database=true: this root already owns this resource. Removal requires a separately reviewed retirement procedure."
  }
}
variable "deploy_monitoring" {
  type    = bool
  default = true
  validation {
    condition     = var.deploy_monitoring
    error_message = "Keep deploy_monitoring=true: this root already owns this resource. Removal requires a separately reviewed retirement procedure."
  }
}
variable "database_engine_version" {
  type    = string
  default = "18.6"
}
variable "db_allowed_security_group_ids" {
  type    = list(string)
  default = []
}
variable "monitoring_chart_version" {
  type    = string
  default = "93.2.2"
}

variable "continuity_jenkins_values" {
  description = "Private deployed values; only for reviewed continuity planning."
  type        = list(string)
  sensitive   = true
  default     = null
}

variable "continuity_argocd_values" {
  description = "Private deployed values; only for reviewed continuity planning."
  type        = list(string)
  sensitive   = true
  default     = null
}

variable "continuity_applications_values" {
  description = "Private deployed values; only for reviewed continuity planning."
  type        = list(string)
  sensitive   = true
  default     = null
}

variable "continuity_monitoring_values" {
  description = "Private deployed values; only for reviewed continuity planning."
  type        = list(string)
  sensitive   = true
  default     = null
}

variable "security_profile" {
  description = "Hardened is desired source policy. Continuity is only for reviewed ownership transfer using deployed values; never apply either under HOLD."
  type        = string
  default     = "hardened"
  validation {
    condition     = contains(["hardened", "continuity"], var.security_profile)
    error_message = "Choose hardened desired configuration or explicitly reviewed continuity."
  }
}
variable "private_runner_verified" {
  description = "Confirm endpoint/DNS/security-group access from the actual private execution runner before proposing private-only endpoint changes. This is not deployment authorization."
  type        = bool
  default     = false
  validation {
    condition     = var.security_profile == "continuity" || var.private_runner_verified
    error_message = "Hardened planning requires private_runner_verified=true after read-only connectivity evidence. Migration HOLD and separate deployment approval still apply."
  }
}

variable "ebs_csi_addon_version" {
  type    = string
  default = null
  validation {
    condition     = !var.enable_ebs_csi || var.ebs_csi_addon_version != null
    error_message = "Supply an AWS-verified compatible EBS CSI add-on version before enabling storage."
  }
}
