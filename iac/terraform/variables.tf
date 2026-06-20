# ---- General ----
variable "project" {
  description = "Project name, used as a resource-name prefix."
  type        = string
  default     = "mmu-sis"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "ap-southeast-1" # Singapore (closest to Malaysia)
}

# ---- Networking ----
variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "az_count" {
  description = "Number of AZs (>= 2 for high availability)."
  type        = number
  default     = 2
}

variable "enable_ipv6" {
  description = "Enable dual-stack IPv6 (bonus)."
  type        = bool
  default     = false
}

variable "admin_cidr" {
  description = "CIDR allowed to reach the ALB on 80/443. Tighten to known IPs where possible."
  type        = string
  default     = "0.0.0.0/0"
}

# ---- Database ----
variable "db_name" {
  type    = string
  default = "sis"
}

variable "db_username" {
  type    = string
  default = "sis_admin"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "db_engine_version" {
  type    = string
  default = "8.0"
}

variable "db_multi_az" {
  type    = bool
  default = true
}

variable "db_deletion_protection" {
  type    = bool
  default = false
}

variable "backup_retention_days" {
  type    = number
  default = 7
}

# ---- Application / compute ----
variable "app_image" {
  description = "Container image URI. Leave empty to default to <ecr-repo>:latest (push after first apply)."
  type        = string
  default     = ""
}

variable "app_port" {
  type    = number
  default = 80
}

variable "app_desired_count" {
  type    = number
  default = 2
}

variable "task_cpu" {
  type    = string
  default = "256"
}

variable "task_memory" {
  type    = string
  default = "512"
}

# ---- TLS ----
variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS. Leave empty to auto-generate a self-signed certificate."
  type        = string
  default     = ""
}

variable "enable_self_signed_cert" {
  description = "Generate + import a self-signed certificate so HTTPS works with no domain/cost."
  type        = bool
  default     = true
}

# ---- Logging / monitoring ----
variable "log_retention_days" {
  type    = number
  default = 90
}

variable "waf_rate_limit" {
  description = "Requests per 5 minutes per IP before WAF blocks."
  type        = number
  default     = 2000
}

variable "alarm_email" {
  description = "Optional email subscribed to security alarms."
  type        = string
  default     = ""
}

# ---- Bonus ----
variable "enable_inspector" {
  description = "Enable Amazon Inspector enhanced ECR scanning (bonus; may incur cost)."
  type        = bool
  default     = false
}
