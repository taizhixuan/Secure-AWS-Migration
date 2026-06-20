output "application_url" {
  description = "Open this in a browser after the image is pushed and tasks are healthy."
  value       = module.compute.https_enabled ? "https://${module.compute.alb_dns_name}" : "http://${module.compute.alb_dns_name}"
}

output "alb_dns_name" {
  value = module.compute.alb_dns_name
}

output "ecr_repository_url" {
  description = "Build, tag and push the application image here."
  value       = module.compute.ecr_repository_url
}

output "ecs_cluster_name" {
  value = module.compute.ecs_cluster_name
}

output "ecs_service_name" {
  value = module.compute.ecs_service_name
}

output "app_log_group" {
  value = module.compute.app_log_group
}

output "app_subnet_ids" {
  description = "Private app-tier subnet IDs (for one-off run-task migrations)."
  value       = module.network.app_subnet_ids
}

output "app_security_group_id" {
  description = "App-tier security group ID (for one-off run-task migrations)."
  value       = module.security.app_sg_id
}

output "rds_endpoint" {
  value     = module.database.db_endpoint
  sensitive = true
}

output "db_secret_arn" {
  description = "Secrets Manager ARN holding the DB credentials."
  value       = module.database.db_secret_arn
}

output "app_data_bucket" {
  value = module.storage.app_data_bucket
}

output "alb_logs_bucket" {
  value = module.storage.alb_logs_bucket
}

output "cloudtrail_bucket" {
  value = module.observability.cloudtrail_bucket
}

output "cloudtrail_log_group" {
  value = module.observability.cloudtrail_log_group
}

output "kms_key_arn" {
  value = module.security.kms_key_arn
}
