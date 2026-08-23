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

# Better Stack heartbeat ping URLs
#
# These are consumed by the Ansible `heartbeat` role, which cannot read Terraform
# state. Copy each one into the vault by hand after apply, the same arrangement as
# the R2 credentials:
#
#   terraform output -raw heartbeat_url_s1_host
#   ansible-vault edit inventory/group_vars/all/vault.yml
#
# They are marked sensitive because the URL is the only credential involved —
# anyone holding it can report the service as healthy. A replaced heartbeat
# resource issues a new URL, so this is a one-off per heartbeat.

output "heartbeat_url_s1_host" {
  description = "Better Stack heartbeat URL for the s1 host"
  value       = betteruptime_heartbeat.s1_host.url
  sensitive   = true
}

output "heartbeat_url_wallos" {
  description = "Better Stack heartbeat URL for the Wallos container on s1"
  value       = betteruptime_heartbeat.wallos.url
  sensitive   = true
}

output "heartbeat_url_chime" {
  description = "Better Stack heartbeat URL for chime"
  value       = betteruptime_heartbeat.chime.url
  sensitive   = true
}

output "heartbeat_url_babyrite" {
  description = "Better Stack heartbeat URL for babyrite"
  value       = betteruptime_heartbeat.babyrite.url
  sensitive   = true
}

output "heartbeat_url_honeypot" {
  description = "Better Stack heartbeat URL for honeypot"
  value       = betteruptime_heartbeat.honeypot.url
  sensitive   = true
}

output "heartbeat_url_hermes" {
  description = "Better Stack heartbeat URL for hermes"
  value       = betteruptime_heartbeat.hermes.url
  sensitive   = true
}

output "heartbeat_url_backup" {
  description = "Better Stack heartbeat URL for the weekly restic backup"
  value       = betteruptime_heartbeat.backup.url
  sensitive   = true
}

output "status_page_url" {
  description = "Public status page URL"
  value       = "https://${betteruptime_status_page.m1sk9.custom_domain}"
}
