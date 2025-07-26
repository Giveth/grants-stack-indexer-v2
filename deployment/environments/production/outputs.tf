output "load_balancer_dns_name" {
  description = "DNS name of the load balancer"
  value       = module.simple_load_balancer.load_balancer_dns_name
}

output "cluster_name" {
  description = "ECS cluster name"
  value       = module.simple_compute.cluster_name
}

output "image_tag" {
  description = "Currently deployed image tag"
  value       = var.BLUE_API_IMAGE_TAG
}

output "api_gateway_url" {
  value = module.api_gateway.api_gateway_url
}

output "rds_endpoint" {
  description = "RDS database endpoint"
  value       = module.storage.rds_endpoint
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = module.networking.public_subnets
}

output "processing_security_group_id" {
  description = "Processing security group ID"
  value       = module.networking.processing_security_group_id
}
