# Cloudflare Zero Trust Access for Arcane

resource "cloudflare_zero_trust_access_identity_provider" "github" {
  account_id = local.cloudflare_account_id
  name       = "GitHub"
  type       = "github"
  config = {
    client_id     = var.github_client_id
    client_secret = var.github_client_secret
  }
}

resource "cloudflare_zero_trust_access_policy" "acrane" {
  account_id = local.cloudflare_account_id
  name       = "Allow me@m1sk9.dev"
  decision   = "allow"

  include = [{
    email = {
      email = "me@m1sk9.dev"
    }
  }]
}

resource "cloudflare_zero_trust_access_application" "acrane" {
  account_id       = local.cloudflare_account_id
  name             = "Arcane"
  domain           = "acrane.m1sk9.dev"
  type             = "self_hosted"
  session_duration = "24h"

  allowed_idps = [cloudflare_zero_trust_access_identity_provider.github.id]

  policies = [{
    id         = cloudflare_zero_trust_access_policy.acrane.id
    precedence = 1
  }]
}
