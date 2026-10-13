# Cloudflare outputs

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

output "heartbeat_url_s2_host" {
  description = "Better Stack heartbeat URL for the s2 host"
  value       = betteruptime_heartbeat.s2_host.url
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

output "heartbeat_url_pythia" {
  description = "Better Stack heartbeat URL for pythia"
  value       = betteruptime_heartbeat.pythia.url
  sensitive   = true
}

output "status_page_url" {
  description = "Public status page URL"
  value       = "https://${betteruptime_status_page.m1sk9.custom_domain}"
}

# k3s cluster access (ArgoCD and Grafana)
#
# These feed SealedSecrets and the ArgoCD / Grafana configuration under k8s/, so
# they are read with `terraform output` and sealed by hand rather than copied
# into the vault. The secrets are sensitive for the same reason as the heartbeat
# URLs above: each one is the only credential involved.

output "k8s_tunnel_token" {
  description = "Connector token for the k8s Cloudflare Tunnel"
  value       = data.cloudflare_zero_trust_tunnel_cloudflared_token.k8s.token
  sensitive   = true
}

output "argocd_oidc_issuer" {
  description = "OIDC issuer URL of the ArgoCD SSO application"
  value       = "https://${data.cloudflare_zero_trust_organization.this.auth_domain}/cdn-cgi/access/sso/oidc/${cloudflare_zero_trust_access_application.argocd_sso.saas_app.client_id}"
}

output "argocd_oidc_client_id" {
  description = "OIDC client ID of the ArgoCD SSO application"
  value       = cloudflare_zero_trust_access_application.argocd_sso.saas_app.client_id
}

output "argocd_oidc_client_secret" {
  description = "OIDC client secret of the ArgoCD SSO application"
  value       = cloudflare_zero_trust_access_application.argocd_sso.saas_app.client_secret
  sensitive   = true
}

output "grafana_oidc_issuer" {
  description = "OIDC issuer URL of the Grafana SSO application"
  value       = "https://${data.cloudflare_zero_trust_organization.this.auth_domain}/cdn-cgi/access/sso/oidc/${cloudflare_zero_trust_access_application.grafana_sso.saas_app.client_id}"
}

output "grafana_oidc_client_id" {
  description = "OIDC client ID of the Grafana SSO application"
  value       = cloudflare_zero_trust_access_application.grafana_sso.saas_app.client_id
}

output "grafana_oidc_client_secret" {
  description = "OIDC client secret of the Grafana SSO application"
  value       = cloudflare_zero_trust_access_application.grafana_sso.saas_app.client_secret
  sensitive   = true
}
