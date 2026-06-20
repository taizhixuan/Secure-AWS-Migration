variable "name_prefix" {
  type = string
}

variable "db_secret_arn" {
  description = "Secrets Manager ARN the execution role may read to inject DB credentials."
  type        = string
}

variable "kms_key_arn" {
  type = string
}

variable "app_data_bucket_arn" {
  description = "App data S3 bucket ARN the task role may use."
  type        = string
}
