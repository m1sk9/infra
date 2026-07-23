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
        hostname = "dozzle-s1.m1sk9.dev"
        service  = "http://localhost:8181"
      },
      {
        hostname = "books.m1sk9.dev"
        service  = "http://localhost:8384"
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

# DNS Record for Dozzle (Docker log viewer)
resource "cloudflare_dns_record" "dozzle_s1" {
  zone_id = local.cloudflare_zone_id
  name    = "dozzle-s1"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.s1.id}.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1
  proxied = true
  comment = "Cloudflare Tunnel - Dozzle (s1)"
}

# DNS Record for PdfDing (PDF library manager)
resource "cloudflare_dns_record" "pdfding" {
  zone_id = local.cloudflare_zone_id
  name    = "books"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.s1.id}.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1
  proxied = true
  comment = "Cloudflare Tunnel - PdfDing (s1)"
}
