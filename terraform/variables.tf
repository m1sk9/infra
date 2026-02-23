variable "cloudflare_api_token" {
  description = "A Cloudflare API token"
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "github_client_id" {
  description = "GitHub OAuth App Client ID for Cloudflare Access"
  type        = string
  sensitive   = true
}

variable "github_client_secret" {
  description = "GitHub OAuth App Client Secret for Cloudflare Access"
  type        = string
  sensitive   = true
}
