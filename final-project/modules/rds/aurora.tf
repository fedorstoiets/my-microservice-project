resource "aws_rds_cluster" "aurora" {
  count = var.use_aurora ? 1 : 0

  cluster_identifier              = var.name
  engine                          = local.resolved_engine
  engine_version                  = data.aws_rds_engine_version.selected.version_actual
  engine_mode                     = "provisioned"
  database_name                   = var.db_name
  master_username                 = var.master_username
  manage_master_user_password     = true
  db_subnet_group_name            = aws_db_subnet_group.main.name
  vpc_security_group_ids          = [aws_security_group.database.id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora[0].name
  storage_encrypted               = true
  backup_retention_period         = var.backup_retention_period
  deletion_protection             = var.deletion_protection
  skip_final_snapshot             = var.skip_final_snapshot
  final_snapshot_identifier       = var.skip_final_snapshot ? null : "${var.name}-final"
  apply_immediately               = var.apply_immediately
  copy_tags_to_snapshot           = true
  tags                            = var.tags
}

resource "aws_rds_cluster_instance" "aurora" {
  count = var.use_aurora ? var.aurora_instance_count : 0

  identifier                 = "${var.name}-${count.index + 1}"
  cluster_identifier         = aws_rds_cluster.aurora[0].id
  instance_class             = var.instance_class
  engine                     = local.resolved_engine
  engine_version             = aws_rds_cluster.aurora[0].engine_version
  db_subnet_group_name       = aws_db_subnet_group.main.name
  db_parameter_group_name    = var.engine == "mysql" ? aws_db_parameter_group.aurora_mysql[0].name : null
  publicly_accessible        = false
  auto_minor_version_upgrade = true
  apply_immediately          = var.apply_immediately
  tags                       = merge(var.tags, { Role = count.index == 0 ? "Writer" : "Replica" })
}
