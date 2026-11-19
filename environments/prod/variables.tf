variable "aws_region" {
  type    = string
  default = "ca-central-1"
}
variable "environment" {
  type    = string
  default = "prod"
}
variable "vpc_cidr" {
  type    = string
  default = "10.40.0.0/16"
}
variable "nat_mode" {
  type    = string
  default = "none"
}
