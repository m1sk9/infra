# Cloudflare Zero Trust Access

resource "cloudflare_zero_trust_access_identity_provider" "github" {
  account_id = local.cloudflare_account_id
  name       = "GitHub"
  type       = "github"
  config = {
    client_id     = var.github_client_id
    client_secret = var.github_client_secret
  }
}

# Cloudflare Zero Trust Access for Dozzle

# nanai10a@outlook.jp gets the same access as me, which is safe only because
# Dozzle runs with shell and container actions disabled. Access cannot pass
# per-user roles to Dozzle, so re-enabling either would hand them to every
# address listed here.
resource "cloudflare_zero_trust_access_policy" "dozzle" {
  account_id = local.cloudflare_account_id
  name       = "Allow Dozzle viewers"
  decision   = "allow"

  include = [
    {
      email = {
        email = "me@m1sk9.dev"
      }
    },
    {
      email = {
        email = "nanai10a@outlook.jp"
      }
    },
  ]
}

resource "cloudflare_zero_trust_access_application" "dozzle" {
  account_id       = local.cloudflare_account_id
  name             = "Dozzle"
  domain           = "dozzle-s1.m1sk9.dev"
  type             = "self_hosted"
  session_duration = "24h"

  allowed_idps = [cloudflare_zero_trust_access_identity_provider.github.id]

  policies = [{
    id         = cloudflare_zero_trust_access_policy.dozzle.id
    precedence = 1
  }]
}
