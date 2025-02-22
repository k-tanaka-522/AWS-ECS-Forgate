variable "environment" {
  description = "Environment (dev/stg/prd)"
  type        = string
}

variable "app_name" {
  description = "Application name"
  type        = string
}

variable "callback_urls" {
  description = "List of allowed callback URLs for the identity provider"
  type        = list(string)
  default     = ["http://localhost:3000"]
}

variable "logout_urls" {
  description = "List of allowed logout URLs for the identity provider"
  type        = list(string)
  default     = ["http://localhost:3000"]
}

variable "allowed_oauth_scopes" {
  description = "List of allowed OAuth scopes"
  type        = list(string)
  default     = ["email", "openid", "profile"]
}

variable "allowed_oauth_flows" {
  description = "List of allowed OAuth flows"
  type        = list(string)
  default     = ["code"]
}
