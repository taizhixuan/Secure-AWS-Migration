/*
 * Database module: Amazon RDS for MySQL (Multi-AZ, encrypted) plus a generated
 * master password stored in AWS Secrets Manager. The RDS lives in the isolated
 * data subnets and only accepts traffic from the app security group.
 */

resource "random_password" "db" {
  length           = 24
  special          = true
  override_special = "!#%*-_=+" # safe set for MySQL / connection strings
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-db-subnets"
  subnet_ids = var.data_subnet_ids
  tags       = { Name = "${var.name_prefix}-db-subnets" }
}

resource "aws_db_instance" "this" {
  identifier     = "${var.name_prefix}-mysql"
  engine         = "mysql"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true
  kms_key_id        = var.kms_key_arn

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result
  port     = 3306

  multi_az               = var.db_multi_az
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.db_sg_id]
  publicly_accessible    = false

  backup_retention_period    = var.backup_retention_days
  copy_tags_to_snapshot      = true
  deletion_protection        = var.db_deletion_protection
  skip_final_snapshot        = true # set false in production
  final_snapshot_identifier  = null
  auto_minor_version_upgrade = true
  apply_immediately          = true

  enabled_cloudwatch_logs_exports = ["error", "slowquery"]

  tags = { Name = "${var.name_prefix}-mysql" }
}

# Store credentials + connection info in Secrets Manager (encrypted with the CMK).
resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.name_prefix}/db-credentials"
  description             = "RDS MySQL credentials for the SIS application"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = 0 # allow immediate re-create during coursework redeploys

  tags = { Name = "${var.name_prefix}-db-secret" }
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db.result
    host     = aws_db_instance.this.address
    port     = aws_db_instance.this.port
    dbname   = var.db_name
    engine   = "mysql"
  })
}
