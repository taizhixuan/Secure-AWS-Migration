variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "app_subnet_ids" {
  type = list(string)
}

variable "alb_sg_id" {
  type = string
}

variable "app_sg_id" {
  type = string
}

variable "execution_role_arn" {
  type = string
}

variable "task_role_arn" {
  type = string
}

variable "db_secret_arn" {
  type = string
}

variable "db_name" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "alb_logs_bucket" {
  type = string
}

variable "waf_acl_arn" {
  type = string
}

variable "app_image" {
  description = "Container image URI. If empty, defaults to <this-repo>:latest (push the image after the first apply)."
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

variable "certificate_arn" {
  description = "ACM certificate ARN for the HTTPS listener. If empty and enable_self_signed_cert is true, one is generated."
  type        = string
  default     = ""
}

variable "enable_self_signed_cert" {
  description = "Generate and import a self-signed certificate so HTTPS works with zero cost / no domain."
  type        = bool
  default     = true
}

variable "enable_ipv6" {
  type    = bool
  default = false
}

variable "log_retention_days" {
  type    = number
  default = 90
}
