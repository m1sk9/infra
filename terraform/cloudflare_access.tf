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

# Cloudflare Zero Trust Access for the k3s cluster (ArgoCD and Grafana)
#
# Each app is covered twice. A self-hosted application puts the hostname behind
# the GitHub IdP, so nothing about ArgoCD or Grafana is reachable before sign-in.
# A SaaS application then makes Access the OIDC provider for the app's own login,
# which is what lets each app map the signed-in email to a role — a self-hosted
# policy alone gives every allowed address the same access.
#
# Why Access as the OIDC provider rather than Dex: ArgoCD cannot use GitHub
# directly, and running Dex only to front the same IdP would add a component and
# a second set of OAuth credentials.
#
# The break-glass path is the local admin account in each app, which sits behind
# the self-hosted policy but not behind OIDC.
resource "cloudflare_zero_trust_access_policy" "k8s_admins" {
  account_id = local.cloudflare_account_id
  name       = "Allow k8s admins"
  decision   = "allow"

  include = [{
    email = {
      email = "me@m1sk9.dev"
    }
  }]
}

resource "cloudflare_zero_trust_access_application" "argocd" {
  account_id       = local.cloudflare_account_id
  name             = "ArgoCD"
  domain           = "argocd.m1sk9.dev"
  type             = "self_hosted"
  session_duration = "24h"

  allowed_idps = [cloudflare_zero_trust_access_identity_provider.github.id]

  policies = [{
    id         = cloudflare_zero_trust_access_policy.k8s_admins.id
    precedence = 1
  }]
}

resource "cloudflare_zero_trust_access_application" "grafana" {
  account_id       = local.cloudflare_account_id
  name             = "Grafana"
  domain           = "grafana.m1sk9.dev"
  type             = "self_hosted"
  session_duration = "24h"

  allowed_idps = [cloudflare_zero_trust_access_identity_provider.github.id]

  policies = [
    {
      id         = cloudflare_zero_trust_access_policy.k8s_admins.id
      precedence = 1
    },
    {
      id         = cloudflare_zero_trust_access_policy.grafana_mcp.id
      precedence = 2
    },
  ]
}

resource "cloudflare_zero_trust_access_application" "argocd_sso" {
  account_id = local.cloudflare_account_id
  name       = "ArgoCD SSO"
  type       = "saas"

  allowed_idps = [cloudflare_zero_trust_access_identity_provider.github.id]

  saas_app = {
    auth_type     = "oidc"
    redirect_uris = ["https://argocd.m1sk9.dev/auth/callback"]
    grant_types   = ["authorization_code"]
    scopes        = ["openid", "email", "profile"]
  }

  policies = [{
    id         = cloudflare_zero_trust_access_policy.k8s_admins.id
    precedence = 1
  }]
}

resource "cloudflare_zero_trust_access_application" "grafana_sso" {
  account_id = local.cloudflare_account_id
  name       = "Grafana SSO"
  type       = "saas"

  allowed_idps = [cloudflare_zero_trust_access_identity_provider.github.id]

  saas_app = {
    auth_type     = "oidc"
    redirect_uris = ["https://grafana.m1sk9.dev/login/generic_oauth"]
    grant_types   = ["authorization_code"]
    scopes        = ["openid", "email", "profile"]
  }

  policies = [{
    id         = cloudflare_zero_trust_access_policy.k8s_admins.id
    precedence = 1
  }]
}

# The team domain (<team>.cloudflareaccess.com) is part of every OIDC endpoint.
data "cloudflare_zero_trust_organization" "this" {
  account_id = local.cloudflare_account_id
}

# Uptime probe access for ArgoCD and Grafana health endpoints
#
# Why a service token at all: Access answers unauthenticated requests at the edge
# with a redirect to the IdP, before the origin is ever consulted. An external
# monitor that treats that redirect as success would be confirming Cloudflare is
# up and nothing else — it would keep reporting green with the cluster down. The
# token is what lets a probe reach the Pod and observe a real response.
#
# Why separate path-scoped applications instead of adding the token to the
# self-hosted policies above: Cloudflare evaluates the most specific path first and
# does not inherit rules from the broader application, so each of these grants one
# health path and nothing else. ArgoCD's /healthz and Grafana's /api/health need no
# login and return a bare status, so a leaked token buys an attacker that and
# nothing more, while the apps themselves stay behind the GitHub IdP.
#
# Note that this also means those two paths stop being reachable from a browser
# signed in as an admin — non_identity admits service tokens only.
resource "cloudflare_zero_trust_access_service_token" "uptime" {
  account_id = local.cloudflare_account_id
  name       = "betterstack-uptime"
  duration   = "8760h" # 1 year; rotate by bumping client_secret_version
}

resource "cloudflare_zero_trust_access_policy" "uptime_probe" {
  account_id = local.cloudflare_account_id
  name       = "Allow Better Stack uptime probe"
  decision   = "non_identity"

  include = [{
    service_token = {
      token_id = cloudflare_zero_trust_access_service_token.uptime.id
    }
  }]
}

resource "cloudflare_zero_trust_access_application" "argocd_health" {
  account_id = local.cloudflare_account_id
  name       = "ArgoCD Health"
  domain     = "argocd.m1sk9.dev/healthz"
  type       = "self_hosted"

  policies = [{
    id         = cloudflare_zero_trust_access_policy.uptime_probe.id
    precedence = 1
  }]
}

resource "cloudflare_zero_trust_access_application" "grafana_health" {
  account_id = local.cloudflare_account_id
  name       = "Grafana Health"
  domain     = "grafana.m1sk9.dev/api/health"
  type       = "self_hosted"

  policies = [{
    id         = cloudflare_zero_trust_access_policy.uptime_probe.id
    precedence = 1
  }]
}

# Grafana MCP server access
#
# The MCP server runs on a workstation and cannot complete the GitHub IdP login,
# so it presents a service token at the edge and a Grafana service account token
# (Viewer) at the origin. The Access token alone gets no further than Grafana's
# own login, which is why it is admitted to the whole hostname rather than scoped
# to /api like the health probes.
#
# Why a separate token from `uptime`: that one is stored in Better Stack, this one
# on a workstation; keeping them apart lets either be revoked without the other.
resource "cloudflare_zero_trust_access_service_token" "grafana_mcp" {
  account_id = local.cloudflare_account_id
  name       = "grafana-mcp"
  duration   = "8760h" # 1 year; rotate by bumping client_secret_version
}

resource "cloudflare_zero_trust_access_policy" "grafana_mcp" {
  account_id = local.cloudflare_account_id
  name       = "Allow Grafana MCP server"
  decision   = "non_identity"

  include = [{
    service_token = {
      token_id = cloudflare_zero_trust_access_service_token.grafana_mcp.id
    }
  }]
}
