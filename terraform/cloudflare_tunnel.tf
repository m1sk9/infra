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
        hostname = "wallos.m1sk9.dev"
        service  = "http://localhost:8282"
      },
      {
        service = "http_status:404"
      }
    ]
  }
}

# DNS Record for Wallos (Subscription tracker)
resource "cloudflare_dns_record" "wallos" {
  zone_id = local.cloudflare_zone_id
  name    = "wallos"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.s1.id}.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1
  proxied = true
  comment = "Cloudflare Tunnel - Wallos (s1)"
}
