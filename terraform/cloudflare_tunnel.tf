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
        hostname = "acrane.m1sk9.dev"
        service  = "http://localhost:3552"
      },
      {
        service = "http_status:404"
      }
    ]
  }
}

# DNS Record for Arcane (Docker management UI)
resource "cloudflare_dns_record" "acrane" {
  zone_id = local.cloudflare_zone_id
  name    = "acrane"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.s1.id}.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1
  proxied = true
  comment = "Cloudflare Tunnel - Arcane (s1)"
}
