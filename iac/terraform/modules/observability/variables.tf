variable "name_prefix" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "log_retention_days" {
  type    = number
  default = 90
}

variable "force_destroy" {
  type    = bool
  default = true
}

variable "alarm_email" {
  description = "Optional email address subscribed to security alarms (leave empty to skip)."
  type        = string
  default     = ""
}

variable "enable_inspector" {
  description = "Enable Amazon Inspector enhanced scanning for ECR images (bonus). May incur cost."
  type        = bool
  default     = false
}
