/*
 * Root module: composes the network, security, storage, database, IAM, compute
 * and observability modules into the full secure SIS architecture.
 *
 * Dependency order (via outputs):
 *   network -> security -> storage -> database -> iam -> compute
 *                                        \-> observability
 */

locals {
  name_prefix = "${var.project}-${var.environment}"
}

module "network" {
  source = "./modules/network"

  name_prefix = local.name_prefix
  vpc_cidr    = var.vpc_cidr
  az_count    = var.az_count
  enable_ipv6 = var.enable_ipv6
  app_port    = var.app_port
}

module "security" {
  source = "./modules/security"

  name_prefix    = local.name_prefix
  vpc_id         = module.network.vpc_id
  vpc_cidr       = module.network.vpc_cidr
  app_port       = var.app_port
  admin_cidr     = var.admin_cidr
  enable_ipv6    = var.enable_ipv6
  waf_rate_limit = var.waf_rate_limit
}

module "storage" {
  source = "./modules/storage"

  name_prefix         = local.name_prefix
  kms_key_arn         = module.security.kms_key_arn
  log_expiration_days = var.log_retention_days
}

module "database" {
  source = "./modules/database"

  name_prefix            = local.name_prefix
  data_subnet_ids        = module.network.data_subnet_ids
  db_sg_id               = module.security.db_sg_id
  kms_key_arn            = module.security.kms_key_arn
  db_name                = var.db_name
  db_username            = var.db_username
  db_instance_class      = var.db_instance_class
  db_allocated_storage   = var.db_allocated_storage
  db_engine_version      = var.db_engine_version
  db_multi_az            = var.db_multi_az
  db_deletion_protection = var.db_deletion_protection
  backup_retention_days  = var.backup_retention_days
}

module "iam" {
  source = "./modules/iam"

  name_prefix         = local.name_prefix
  db_secret_arn       = module.database.db_secret_arn
  kms_key_arn         = module.security.kms_key_arn
  app_data_bucket_arn = module.storage.app_data_bucket_arn
}

module "compute" {
  source = "./modules/compute"

  name_prefix             = local.name_prefix
  vpc_id                  = module.network.vpc_id
  public_subnet_ids       = module.network.public_subnet_ids
  app_subnet_ids          = module.network.app_subnet_ids
  alb_sg_id               = module.security.alb_sg_id
  app_sg_id               = module.security.app_sg_id
  execution_role_arn      = module.iam.execution_role_arn
  task_role_arn           = module.iam.task_role_arn
  db_secret_arn           = module.database.db_secret_arn
  db_name                 = var.db_name
  kms_key_arn             = module.security.kms_key_arn
  alb_logs_bucket         = module.storage.alb_logs_bucket
  waf_acl_arn             = module.security.waf_acl_arn
  app_image               = var.app_image
  app_port                = var.app_port
  app_desired_count       = var.app_desired_count
  task_cpu                = var.task_cpu
  task_memory             = var.task_memory
  certificate_arn         = var.certificate_arn
  enable_self_signed_cert = var.enable_self_signed_cert
  enable_ipv6             = var.enable_ipv6
  log_retention_days      = var.log_retention_days

  # Ensure the ALB-logs bucket policy exists before the ALB is created.
  depends_on = [module.storage]
}

module "observability" {
  source = "./modules/observability"

  name_prefix        = local.name_prefix
  kms_key_arn        = module.security.kms_key_arn
  log_retention_days = var.log_retention_days
  alarm_email        = var.alarm_email
  enable_inspector   = var.enable_inspector
}
