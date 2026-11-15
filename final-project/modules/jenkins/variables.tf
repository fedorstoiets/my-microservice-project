variable "namespace" { type = string }
variable "source_repo" {
  type = string
  validation {
    condition     = can(regex("^https://[A-Za-z0-9.-]+/[A-Za-z0-9._/-]+$", var.source_repo))
    error_message = "Use a credential-free HTTPS SCM URL; JCasC interpolation must not contain script syntax."
  }
}
variable "service_account" { type = string }

variable "chart_version" {
  type    = string
  default = null
}
variable "source_branch" {
  type    = string
  default = "final-project"
}
variable "existing_claim" {
  type    = string
  default = ""
}
variable "build_config" {
  type    = map(string)
  default = {}
}

variable "existing_claim_sub_path" {
  description = "Use restored only after verified restore into that subdirectory; empty for a fresh home."
  type        = string
  default     = ""
}

variable "values_override" {
  description = "Private deployed Helm values for a migration continuity plan; null uses reviewed source values."
  type        = list(string)
  sensitive   = true
  default     = null
}

variable "persistence_enabled" {
  type    = bool
  default = false
}
