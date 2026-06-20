variable "name_prefix" {
  type = string
}

variable "data_subnet_ids" {
  description = "Private, isolated data-tier subnet IDs."
  type        = list(string)
}

variable "db_sg_id" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

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
