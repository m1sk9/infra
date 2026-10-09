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

variable "betteruptime_api_token" {
  description = "A Better Stack Uptime API token"
  type        = string
  sensitive   = true
  ephemeral   = true
}

# Why the two leak_alert variables are not ephemeral like the API tokens above:
# their values are written into Worker secret bindings, which Terraform keeps in
# state, and ephemeral values cannot flow into a stored attribute.
variable "leak_alert_cloudflare_api_token" {
  description = "Cloudflare API token (Zone Analytics Read on m1sk9.dev) used by the leak-alert Worker"
  type        = string
  sensitive   = true
}

variable "leak_alert_discord_webhook_url" {
  description = "Discord webhook URL the leak-alert Worker posts to"
  type        = string
  sensitive   = true
}
