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

# Cloudflare Zero Trust Access for Wallos

resource "cloudflare_zero_trust_access_policy" "wallos" {
  account_id = local.cloudflare_account_id
  name       = "Allow me@m1sk9.dev"
  decision   = "allow"

  include = [{
    email = {
      email = "me@m1sk9.dev"
    }
  }]
}

resource "cloudflare_zero_trust_access_application" "wallos" {
  account_id       = local.cloudflare_account_id
  name             = "Wallos"
  domain           = "wallos.m1sk9.dev"
  type             = "self_hosted"
  session_duration = "24h"

  allowed_idps = [cloudflare_zero_trust_access_identity_provider.github.id]

  policies = [{
    id         = cloudflare_zero_trust_access_policy.wallos.id
    precedence = 1
  }]
}

# Cloudflare Zero Trust Access for Dozzle

resource "cloudflare_zero_trust_access_policy" "dozzle" {
  account_id = local.cloudflare_account_id
  name       = "Allow me@m1sk9.dev"
  decision   = "allow"

  include = [{
    email = {
      email = "me@m1sk9.dev"
    }
  }]
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

# Cloudflare Zero Trust Access for PdfDing

resource "cloudflare_zero_trust_access_policy" "pdfding" {
  account_id = local.cloudflare_account_id
  name       = "Allow me@m1sk9.dev"
  decision   = "allow"

  include = [{
    email = {
      email = "me@m1sk9.dev"
    }
  }]
}

resource "cloudflare_zero_trust_access_application" "pdfding" {
  account_id       = local.cloudflare_account_id
  name             = "PdfDing"
  domain           = "books.m1sk9.dev"
  type             = "self_hosted"
  session_duration = "24h"

  allowed_idps = [cloudflare_zero_trust_access_identity_provider.github.id]

  policies = [{
    id         = cloudflare_zero_trust_access_policy.pdfding.id
    precedence = 1
  }]
}

# Uptime probe access for PdfDing's health endpoint
#
# Why a service token at all: Access answers unauthenticated requests at the edge
# with a redirect to the IdP, before the origin is ever consulted. An external
# monitor that treats that redirect as success would be confirming Cloudflare is
# up and nothing else — it would keep reporting green with s1 unplugged. The
# token is what lets a probe reach the container and observe a real response.
#
# Why a separate path-scoped application instead of adding the token to the
# PdfDing policy above: Cloudflare evaluates the most specific path first and
# does not inherit rules from the broader application, so this grants /healthz
# and nothing else. PdfDing's HealthView is login_not_required and returns an
# empty 200, so a leaked token buys an attacker a blank page while the library
# itself stays behind the GitHub IdP.
#
# Note that this also means /healthz stops being reachable from a browser signed
# in as me@m1sk9.dev — non_identity admits service tokens only. That is fine for
# a health endpoint, but it does surprise you if you go looking.
resource "cloudflare_zero_trust_access_service_token" "uptime" {
  account_id = local.cloudflare_account_id
  name       = "betterstack-uptime"
  duration   = "8760h" # 1 year; rotate by bumping client_secret_version
}

resource "cloudflare_zero_trust_access_policy" "pdfding_healthz" {
  account_id = local.cloudflare_account_id
  name       = "Allow Better Stack uptime probe"
  decision   = "non_identity"

  include = [{
    service_token = {
      token_id = cloudflare_zero_trust_access_service_token.uptime.id
    }
  }]
}

resource "cloudflare_zero_trust_access_application" "pdfding_healthz" {
  account_id = local.cloudflare_account_id
  name       = "PdfDing Health"
  domain     = "books.m1sk9.dev/healthz"
  type       = "self_hosted"

  policies = [{
    id         = cloudflare_zero_trust_access_policy.pdfding_healthz.id
    precedence = 1
  }]
}
