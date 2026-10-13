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
        hostname = "dozzle-s1.m1sk9.dev"
        service  = "http://localhost:8181"
      },
      {
        service = "http_status:404"
      }
    ]
  }
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

# Cloudflare Tunnel for the k3s cluster (ArgoCD and Grafana)
#
# Unlike the s1 tunnel, the connector is a Deployment inside the cluster, so the
# ingress targets are Service DNS names. Both apps are plain HTTP behind the
# tunnel: TLS ends at Cloudflare, and ArgoCD is run with server.insecure for the
# same reason.

resource "cloudflare_zero_trust_tunnel_cloudflared" "k8s" {
  account_id = local.cloudflare_account_id
  name       = "k8s"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "k8s" {
  account_id = local.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.k8s.id
  config = {
    ingress = [
      {
        hostname = "argocd.m1sk9.dev"
        service  = "http://argocd-server.argocd.svc.cluster.local:80"
      },
      {
        hostname = "grafana.m1sk9.dev"
        service  = "http://monitoring-grafana.monitoring.svc.cluster.local:80"
      },
      {
        service = "http_status:404"
      }
    ]
  }
}

# The connector token is read here and exposed as a sensitive output, to be
# sealed into a SealedSecret by hand — see outputs.tf.
data "cloudflare_zero_trust_tunnel_cloudflared_token" "k8s" {
  account_id = local.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.k8s.id
}

# DNS Record for ArgoCD
resource "cloudflare_dns_record" "argocd" {
  zone_id = local.cloudflare_zone_id
  name    = "argocd"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.k8s.id}.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1
  proxied = true
  comment = "Cloudflare Tunnel - ArgoCD (k8s)"
}

# DNS Record for Grafana
resource "cloudflare_dns_record" "grafana" {
  zone_id = local.cloudflare_zone_id
  name    = "grafana"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.k8s.id}.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1
  proxied = true
  comment = "Cloudflare Tunnel - Grafana (k8s)"
}
