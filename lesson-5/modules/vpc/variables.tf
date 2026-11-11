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
