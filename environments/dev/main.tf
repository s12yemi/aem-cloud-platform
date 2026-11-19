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


# Disabled by default in every environment: VPC-only plans remain inexpensive.
module "application" {
  count                = var.enable_application ? 1 : 0
  source               = "../../modules/application"
  name                 = "aem-cloud-platform"
  environment          = var.environment
  vpc_id               = module.networking.vpc_id
  vpc_cidr             = module.networking.vpc_cidr
  public_subnet_ids    = module.networking.public_subnet_ids
  private_subnet_ids   = module.networking.app_subnet_ids
  instance_type        = var.application_instance_type
  desired_capacity     = var.application_desired_capacity
  max_size             = var.application_max_size
  enable_ssm_endpoints = var.enable_ssm_endpoints
  alarm_email          = var.alarm_email
  tags                 = { CostCenter = "interview-lab" }
}
