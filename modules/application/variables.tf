variable "name" { type = string }
variable "environment" { type = string }
variable "vpc_id" { type = string }
variable "vpc_cidr" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "private_subnet_ids" { type = list(string) }
variable "instance_type" { type = string; default = "t3.micro" }
variable "desired_capacity" { type = number; default = 1 }
variable "max_size" { type = number; default = 2 }
variable "enable_ssm_endpoints" { type = bool; default = false }
variable "alarm_email" { type = string; default = "" }
variable "tags" { type = map(string); default = {} }
