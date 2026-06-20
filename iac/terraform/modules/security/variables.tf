variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "app_port" {
  type    = number
  default = 80
}

variable "admin_cidr" {
  description = "CIDR allowed to reach the ALB on 80/443. Restrict to known IPs where possible."
  type        = string
  default     = "0.0.0.0/0"
}

variable "enable_ipv6" {
  type    = bool
  default = false
}

variable "waf_rate_limit" {
  description = "Requests per 5 minutes per IP before WAF blocks."
  type        = number
  default     = 2000
}
