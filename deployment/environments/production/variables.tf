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

variable "BASTION_SSH_PUBLIC_KEY" {
  description = "SSH public key for bastion host access"
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

variable "BLUE_COINGECKO_API_KEY" {
  description = "Coingecko API key (BLUE)"
  type        = string
  sensitive   = true
}
