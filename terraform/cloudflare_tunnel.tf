# Cloudflare Tunnel for server s1

resource "cloudflare_zero_trust_tunnel_cloudflared" "s1" {
  account_id = local.cloudflare_account_id
  name       = "s1"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "s1" {
  account_id = local.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.s1.id
  config = {
    ingress = [
      {
        hostname = "status.m1sk9.dev"
        service  = "http://localhost:3001"
      },
      {
        hostname = "dashboard.m1sk9.dev"
        service  = "http://localhost:7575"
      },
      {
        service = "http_status:404"
      }
    ]
  }
}

# DNS Record for dashboard service
resource "cloudflare_dns_record" "dashboard" {
  zone_id = local.cloudflare_zone_id
  name    = "dashboard"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.s1.id}.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1
  proxied = true
  comment = "Cloudflare Tunnel - Dashboard"
}

# DNS Record for status monitoring service
resource "cloudflare_dns_record" "status" {
  zone_id = local.cloudflare_zone_id
  name    = "status"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.s1.id}.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1
  proxied = true
  comment = "Cloudflare Tunnel - Status Monitoring"
}
