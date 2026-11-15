variable "ecr_name" {
  description = "ECR repository name"
  type        = string
}

variable "scan_on_push" {
  description = "Enable image scan on push"
  type        = bool
  default     = true
}

variable "immutable_tags" {
  type    = bool
  default = true
}

variable "kms_key_arn" {
  type    = string
  default = null
}
