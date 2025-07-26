variable "app_name" {
  description = "Name of the application"
  type        = string
}

variable "app_environment" {
  description = "Environment (staging, production)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "ecr_repository_url" {
  description = "ECR repository URL for container images"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

variable "database_url" {
  description = "Database connection URL"
  type        = string
}

variable "redis_url" {
  description = "Redis connection URL"
  type        = string
  default     = ""
}

variable "public_subnets" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "api_security_group_id" {
  description = "Security group ID for API service"
  type        = string
}

variable "processing_security_group_id" {
  description = "Security group ID for processing services"
  type        = string
}

variable "api_target_group_arn" {
  description = "Target group ARN for API load balancer"
  type        = string
}

variable "ecs_task_execution_role_arn" {
  description = "ECS task execution role ARN"
  type        = string
}

variable "ecs_task_role_arn" {
  description = "ECS task role ARN"
  type        = string
}

variable "CHAINS" {
  description = "List of blockchain chains to process"
  type = list(object({
    id           = number
    name         = string
    rpcUrls      = list(string)
    fetchLimit   = number
    fetchDelayMs = number
  }))
  default = []
}

variable "coingecko_api_key" {
  description = "CoinGecko API key for pricing data"
  type        = string
  sensitive   = true
}

variable "pricing_source" {
  description = "Pricing source: 'dummy' or 'coingecko'"
  type        = string
  default     = "coingecko"
  validation {
    condition     = contains(["dummy", "coingecko"], var.pricing_source)
    error_message = "PRICING_SOURCE must be either 'dummy' or 'coingecko'."
  }
}

variable "metadata_source" {
  description = "Metadata source configuration"
  type        = string
  default     = "public-gateway"
  validation {
    condition     = contains(["dummy", "public-gateway"], var.metadata_source)
    error_message = "METADATA_SOURCE must be either 'dummy' or 'public-gateway'."
  }
}

variable "public_gateway_urls" {
  description = "List of public IPFS gateway URLs"
  type        = list(string)
  default     = ["https://ipfs.io/ipfs/", "https://gateway.pinata.cloud/ipfs/"]
}

variable "coingecko_api_type" {
  description = "CoinGecko API type"
  type        = string
  default     = "demo"
}

variable "log_level" {
  description = "Application log level"
  type        = string
  default     = "info"
}

variable "indexer_graphql_url" {
  description = "GraphQL endpoint URL for the indexer"
  type        = string
  default     = "http://localhost:8080/v1/graphql"
}
