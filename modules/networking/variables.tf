variable "name" {
  description = "Stable name prefix for network resources."
  type        = string
}
variable "environment" {
  type        = string
  description = "Environment label: dev, staging, or prod."
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}
variable "vpc_cidr" {
  description = "VPC CIDR, sized for six /24 subnets when given a /16."
  type        = string
  validation {
    condition     = can(cidrnetmask(var.vpc_cidr)) && try(tonumber(split("/", var.vpc_cidr)[1]) == 16, false)
    error_message = "Use a valid IPv4 /16 CIDR for this starter network layout."
  }
}
variable "availability_zones" {
  description = "Exactly two AZ names in the region."
  type        = list(string)
  validation {
    condition     = length(var.availability_zones) == 2 && length(distinct(var.availability_zones)) == 2
    error_message = "Specify two distinct availability zones."
  }
}
variable "nat_mode" {
  description = "none (cheap, private workloads lack internet), single (lab), per_az (resilient)."
  type        = string
  default     = "none"
  validation {
    condition     = contains(["none", "single", "per_az"], var.nat_mode)
    error_message = "nat_mode must be none, single, or per_az."
  }
}
variable "enable_s3_gateway_endpoint" {
  description = "Add S3 gateway endpoint to private app route tables (no NAT required for regional S3)."
  type        = bool
  default     = true
}
variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional common resource tags."
}
