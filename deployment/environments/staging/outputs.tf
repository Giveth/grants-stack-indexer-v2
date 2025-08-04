output "active_deployment" {
  value = var.ACTIVE_DEPLOYMENT
}

output "deployment_state" {
  value = var.DEPLOYMENT_STATE
}

output "api_gateway_url" {
  value = module.api_gateway.api_gateway_url
}

# Outputs required by restore database workflow
output "rds_endpoint" {
  value = module.storage.rds_endpoint
}

output "vpc_id" {
  value = module.networking.vpc_id
}

output "public_subnets" {
  value = module.networking.public_subnets
}

output "processing_security_group_id" {
  value = module.networking.processing_security_group_id
}

# Additional useful outputs for blue/green deployment
output "private_subnets" {
  value = module.networking.private_subnets
}

output "rds_security_group_id" {
  value = module.networking.rds_security_group_id
}

output "api_security_group_id" {
  value = module.networking.api_security_group_id
}

output "load_balancer_security_group_id" {
  value = module.networking.load_balancer_security_group_id
}
