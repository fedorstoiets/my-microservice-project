resource "aws_db_instance" "standard" {
  count = var.use_aurora ? 0 : 1

  identifier                  = var.name
  engine                      = local.resolved_engine
  engine_version              = data.aws_rds_engine_version.selected.version_actual
  instance_class              = var.instance_class
  allocated_storage           = var.allocated_storage
  storage_type                = "gp3"
  storage_encrypted           = true
  db_name                     = var.db_name
  username                    = var.master_username
  manage_master_user_password = true
  db_subnet_group_name        = aws_db_subnet_group.main.name
  vpc_security_group_ids      = [aws_security_group.database.id]
  parameter_group_name        = aws_db_parameter_group.standard[0].name
  publicly_accessible         = false
  multi_az                    = var.multi_az
  backup_retention_period     = var.backup_retention_period
  copy_tags_to_snapshot       = true
  deletion_protection         = var.deletion_protection
  skip_final_snapshot         = var.skip_final_snapshot
  final_snapshot_identifier   = var.skip_final_snapshot ? null : "${var.name}-final"
  apply_immediately           = var.apply_immediately
  auto_minor_version_upgrade  = true
  tags                        = var.tags

  lifecycle {
    precondition {
      condition     = !var.use_aurora
      error_message = "Standard RDS requires use_aurora=false."
    }
  }
}
