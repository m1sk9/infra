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

  policies = [{
    id         = cloudflare_zero_trust_access_policy.k8s_admins.id
    precedence = 1
  }]
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
