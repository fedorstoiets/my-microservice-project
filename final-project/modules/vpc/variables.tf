variable "vpc_cidr_block" { type = string }
variable "public_subnets" {
  type = list(string)
  validation {
    condition     = length(var.public_subnets) == 3
    error_message = "Three public subnet CIDR ranges are required."
  }
}
variable "private_subnets" {
  type = list(string)
  validation {
    condition     = length(var.private_subnets) == 3
    error_message = "Three private subnet CIDR ranges are required."
  }
}
variable "availability_zones" {
  type = list(string)
  validation {
    condition     = length(var.availability_zones) == 3
    error_message = "Three availability zones are required."
  }
}
variable "vpc_name" { type = string }
variable "nat_gateway_enabled" { type = bool }

variable "public_subnet_auto_assign_ipv4" {
  type    = bool
  default = false
}
variable "enable_flow_logs" {
  type    = bool
  default = false
  validation {
    condition     = !var.enable_flow_logs || var.flow_logs_kms_key_arn != null
    error_message = "Flow logs require an explicit authorized KMS key."
  }
}
variable "flow_logs_kms_key_arn" {
  type    = string
  default = null
}
