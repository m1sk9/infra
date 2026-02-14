# Cloudflare Tunnel outputs

output "tunnel_id" {
  description = "Cloudflare Tunnel ID for s1"
  value       = cloudflare_zero_trust_tunnel_cloudflared.s1.id
}

output "tunnel_cname" {
  description = "CNAME target for the tunnel"
  value       = "${cloudflare_zero_trust_tunnel_cloudflared.s1.id}.cfargotunnel.com"
}

output "account_id" {
  description = "Cloudflare Account ID"
  value       = local.cloudflare_account_id
}
