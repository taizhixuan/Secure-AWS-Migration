variable "name_prefix" {
  type = string
}

variable "kms_key_arn" {
  description = "CMK ARN used to encrypt the application data bucket."
  type        = string
}

variable "force_destroy" {
  description = "Allow Terraform to delete non-empty buckets (handy for teardown in a coursework account)."
  type        = bool
  default     = true
}

variable "log_expiration_days" {
  type    = number
  default = 90
}
