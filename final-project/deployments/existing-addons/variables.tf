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
variable "existing_oidc_provider_arn" {
  type    = string
  default = null
  validation {
    condition = (var.existing_oidc_provider_arn != null) != var.create_oidc_provider && (
      !var.create_oidc_provider || var.oidc_absence_verified
    )
    error_message = "Reference the actual verified provider, or explicitly attest authoritative absence before approved creation; never guess or duplicate an owned provider."
  }
}
variable "create_oidc_provider" {
  type    = bool
  default = false
}
variable "oidc_absence_verified" {
  type    = bool
  default = false
}
variable "ebs_csi_addon_version" {
  type = string
  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+-eksbuild\\.[0-9]+$", var.ebs_csi_addon_version))
    error_message = "Supply an AWS-verified EBS CSI version compatible with the existing cluster."
  }
}
variable "prepare_jenkins_storage" {
  type    = bool
  default = true
}
variable "enable_eso" {
  type    = bool
  default = false
}
variable "secret_arns" {
  type    = list(string)
  default = []
  validation {
    condition     = (!var.enable_eso || length(var.secret_arns) > 0) && alltrue([for arn in var.secret_arns : can(regex("^arn:[^:]+:secretsmanager:[^:]+:[0-9]+:secret:[^*?]+$", arn))])
    error_message = "ESO requires explicit actual Secrets Manager ARNs; wildcard secret access is prohibited."
  }
}
variable "kms_key_arns" {
  type    = list(string)
  default = []
  validation {
    condition     = alltrue([for arn in var.kms_key_arns : can(regex("^arn:[^:]+:kms:[^:]+:[0-9]+:key/[^*?]+$", arn))])
    error_message = "Use exact actual KMS key ARNs, never wildcard decrypt permissions."
  }
}
