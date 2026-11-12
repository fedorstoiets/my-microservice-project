output "db_type" {
  description = "Aurora or RDS"
  value       = var.use_aurora ? "aurora" : "rds"
}
output "resolved_engine" {
  value = local.resolved_engine
}
output "resolved_engine_version" {
  value = data.aws_rds_engine_version.selected.version_actual
}
output "identifier" {
  value = var.use_aurora ? aws_rds_cluster.aurora[0].id : aws_db_instance.standard[0].id
}
output "arn" {
  value = var.use_aurora ? aws_rds_cluster.aurora[0].arn : aws_db_instance.standard[0].arn
}
output "endpoint" {
  description = "Aurora cluster writer endpoint or standard RDS endpoint."
  value       = var.use_aurora ? aws_rds_cluster.aurora[0].endpoint : aws_db_instance.standard[0].address
}
output "reader_endpoint" {
  value = var.use_aurora ? aws_rds_cluster.aurora[0].reader_endpoint : null
}
output "port" {
  value = local.port
}
output "master_secret_arn" {
  value = var.use_aurora ? aws_rds_cluster.aurora[0].master_user_secret[0].secret_arn : aws_db_instance.standard[0].master_user_secret[0].secret_arn
}
output "parameter_group_name" {
  value = var.use_aurora ? aws_rds_cluster_parameter_group.aurora[0].name : aws_db_parameter_group.standard[0].name
}
output "subnet_group_name" {
  value = aws_db_subnet_group.main.name
}
output "security_group_id" {
  value = aws_security_group.database.id
}
