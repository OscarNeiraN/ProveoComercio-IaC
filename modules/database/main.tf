resource "aws_db_subnet_group" "main" {
  count      = var.create_db ? 1 : 0
  name       = lower("${var.project_name}-db-subnet-group")
  subnet_ids = var.subnet_ids

  tags = {
    Name = lower("${var.project_name}-db-subnet-group")
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_db_instance" "mysql" {
  count = var.create_db ? 1 : 0

  allocated_storage = var.db_config.storage
  engine            = var.db_config.engine
  engine_version    = var.db_config.engine_version
  instance_class    = var.db_config.instance_class
  db_name           = var.db_config.name

  identifier = lower("${var.project_name}-db")

  username                   = var.db_config.username
  password                   = var.db_config.password
  port                       = 3306
  publicly_accessible        = false
  multi_az                   = try(var.db_config.multi_az, false)
  storage_encrypted          = try(var.db_config.storage_encrypted, true)
  backup_retention_period    = try(var.db_config.backup_retention_period, 7)
  deletion_protection        = try(var.db_config.deletion_protection, false)
  skip_final_snapshot        = true
  auto_minor_version_upgrade = true
  apply_immediately          = true
  copy_tags_to_snapshot      = true
  vpc_security_group_ids     = [var.security_group_id]
  db_subnet_group_name       = aws_db_subnet_group.main[0].name

  tags = {
    Name = lower("${var.project_name}-db")
  }

  lifecycle {
    prevent_destroy = true
  }
}
