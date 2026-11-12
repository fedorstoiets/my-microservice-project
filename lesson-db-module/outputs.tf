output "db_type" {
  description = "Aurora or standard RDS; null when deploy_database=false."
  value       = var.deploy_database ? module.rds[0].db_type : null
}
output "endpoint" {
  description = "Private write endpoint; never includes a password."
  value       = var.deploy_database ? module.rds[0].endpoint : null
}
output "reader_endpoint" {
  description = "Aurora read endpoint (null for standard RDS)."
  value       = var.deploy_database ? module.rds[0].reader_endpoint : null
}
output "port" {
  value = var.deploy_database ? module.rds[0].port : null
}
output "database_identifier" {
  value = var.deploy_database ? module.rds[0].identifier : null
}
output "database_arn" {
  value = var.deploy_database ? module.rds[0].arn : null
}
output "master_secret_arn" {
  description = "AWS Secrets Manager ARN for AWS-managed master password. Read access must be controlled through IAM."
  value       = var.deploy_database ? module.rds[0].master_secret_arn : null
}
output "parameter_group_name" {
  value = var.deploy_database ? module.rds[0].parameter_group_name : null
}
output "db_subnet_group_name" {
  value = var.deploy_database ? module.rds[0].subnet_group_name : null
}
output "security_group_id" {
  value = var.deploy_database ? module.rds[0].security_group_id : null
}
output "resolved_engine" {
  value = var.deploy_database ? module.rds[0].resolved_engine : null
}
output "resolved_engine_version" {
  value = var.deploy_database ? module.rds[0].resolved_engine_version : null
}
