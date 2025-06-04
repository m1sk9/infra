variable "cloudflare_api_token" {
  description = "A Cloudflare API token"
  type        = string
  sensitive   = true
  ephemeral   = true
}
