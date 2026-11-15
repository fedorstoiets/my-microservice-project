variable "aws_region" { type = string }
variable "stack_name" {
  type = string
  validation {
    condition     = can(regex("^goaldevops-v2-[a-z0-9-]+$", var.stack_name))
    error_message = "New environment names must begin goaldevops-v2-; never reuse existing lesson identifiers."
  }
}
variable "kubernetes_version" {
  type = string
  validation {
    condition     = can(regex("^1\\.[0-9]+$", var.kubernetes_version))
    error_message = "Supply an AWS-verified supported EKS minor version."
  }
}
variable "node_instance_type" {
  type    = string
  default = "t3.large"
}
variable "database_engine_version" {
  type     = string
  nullable = false
}
variable "database_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "ebs_csi_addon_version" { type = string }
variable "vpc_cni_addon_version" { type = string }
