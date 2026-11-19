variable "aws_region" {
  type    = string
  default = "ca-central-1"
}
variable "environment" {
  type    = string
  default = "dev"
}
variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}
variable "nat_mode" {
  type    = string
  default = "none"
}

variable "enable_application" {
  type    = bool
  default = false
}

variable "application_instance_type" {
  type    = string
  default = "t3.micro"
}

variable "application_desired_capacity" {
  type    = number
  default = 1
}

variable "application_max_size" {
  type    = number
  default = 2
}

variable "enable_ssm_endpoints" {
  type    = bool
  default = false
}

variable "alarm_email" {
  type    = string
  default = ""
}