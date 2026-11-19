output "vpc_id" { value = module.networking.vpc_id }
output "public_subnet_ids" { value = module.networking.public_subnet_ids }
output "app_subnet_ids" { value = module.networking.app_subnet_ids }
output "database_subnet_ids" { value = module.networking.database_subnet_ids }
output "nat_gateway_ids" { value = module.networking.nat_gateway_ids }
output "s3_gateway_endpoint_id" { value = module.networking.s3_gateway_endpoint_id }

output "application_alb_dns" {
  value = var.enable_application ? module.application[0].alb_dns_name : null
}
output "application_alarm_name" {
  value = var.enable_application ? module.application[0].alarm_name : null
}
