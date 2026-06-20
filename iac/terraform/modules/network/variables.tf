variable "name_prefix" {
  description = "Prefix for resource names, e.g. mmu-sis-prod."
  type        = string
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the VPC."
  type        = string
}

variable "az_count" {
  description = "Number of Availability Zones to span (>= 2 for high availability)."
  type        = number
}

variable "enable_ipv6" {
  description = "Enable dual-stack IPv6 addressing (bonus)."
  type        = bool
  default     = false
}

variable "app_port" {
  description = "Container port the application listens on (used by the app-tier NACL)."
  type        = number
  default     = 80
}
