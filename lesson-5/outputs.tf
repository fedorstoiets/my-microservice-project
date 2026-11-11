output "state_bucket_url" {
  description = "S3 URL holding the remote Terraform state"
  value       = module.s3_backend.bucket_url
}

output "dynamodb_lock_table" {
  description = "Legacy DynamoDB state lock table"
  value       = module.s3_backend.table_name
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "nat_gateway_id" {
  value = module.vpc.nat_gateway_id
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}
