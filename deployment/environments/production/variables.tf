################################################################
####################### SIMPLIFIED DEPLOYMENT ##################
################################################################

# Only the variables actually needed for simplified deployment

#########################################################
####################### SHARED ##########################
#########################################################

variable "AWS_REGION" {
  description = "The region of the application"
  type        = string
}

variable "APP_NAME" {
  description = "The name of the application"
  type        = string
}

variable "APP_ENVIRONMENT" {
  description = "The environment of the application"
  type        = string
}

variable "DATALAYER_PG_PASSWORD" {
  description = "Datalayer postgres password"
  type        = string
  sensitive   = true
}

variable "DATALAYER_PG_USER" {
  description = "Datalayer postgres user"
  type        = string
}

#########################################################
####################### BLUE VARIABLES ##################
#########################################################
# Using BLUE variables for simplified deployment

variable "BLUE_API_IMAGE_TAG" {
  description = "API image tag (BLUE)"
  type        = string
}

variable "BLUE_CHAINS" {
  description = "Chains to be indexed (BLUE)"
  type = list(object({
    id           = number
    name         = string
    rpcUrls      = list(string)
    fetchLimit   = number
    fetchDelayMs = number
  }))
  sensitive = false
}

variable "BLUE_DATALAYER_PG_DB_NAME" {
  description = "Database name (BLUE)"
  type        = string
}

variable "BLUE_API_IMAGE_TAG" {
  description = "API image tag (BLUE)"
  type        = string
  default     = "latest"
}

variable "BLUE_COINGECKO_API_KEY" {
  description = "Coingecko API key (BLUE)"
  type        = string
  sensitive   = true
}

variable "BLUE_PRICING_SOURCE" {
  description = "Pricing source (BLUE)"
  type        = string
  default     = "coingecko"
}

variable "BLUE_METADATA_SOURCE" {
  description = "Metadata source (BLUE)"
  type        = string
  default     = "public-gateway"
}

variable "BLUE_PUBLIC_GATEWAY_URLS" {
  description = "Public gateway URLs (BLUE)"
  type        = list(string)
  default     = ["https://ipfs.io", "https://dweb.link"]
}

variable "BLUE_COINGECKO_API_TYPE" {
  description = "CoinGecko API type (BLUE)"
  type        = string
  default     = "demo"
}

variable "BLUE_LOG_LEVEL" {
  description = "Log level (BLUE)"
  type        = string
  default     = "info"
}

variable "BLUE_INDEXER_GRAPHQL_URL" {
  description = "Indexer GraphQL URL (BLUE)"
  type        = string
  default     = "http://localhost:8080/v1/graphql"
}
