data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  az_names = slice(sort(data.aws_availability_zones.available.names), 0, 2)
}

module "networking" {
  source                     = "../../modules/networking"
  name                       = "aem-cloud-platform"
  environment                = var.environment
  vpc_cidr                   = var.vpc_cidr
  availability_zones         = local.az_names
  nat_mode                   = var.nat_mode
  enable_s3_gateway_endpoint = true
  tags = {
    CostCenter = "interview-lab"
  }
}
