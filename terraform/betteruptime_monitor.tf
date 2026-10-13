# Better Stack monitors (external HTTP checks)

locals {
  # The free plan floor. Asking for less than this is rejected — 30s checks are
  # a paid feature.
  monitor_check_frequency = 180

  # Two regions so that a single unhealthy probe location does not read as an
  # outage. "as" is the closest to the origin, "us" is the control.
  monitor_regions = ["as", "us"]

  # Valid options for HTTP monitors are 2, 3, 5, 10, 15, 30, 45 and 60 seconds.
  # 10 is generous for Cloudflare-fronted hosts.
  monitor_request_timeout = 10

  # Wait one further check before opening or closing an incident, so a single
  # dropped request does not page.
  monitor_confirmation_period = 180
  monitor_recovery_period     = 180
}

# argocd.m1sk9.dev and grafana.m1sk9.dev (Access-protected, behind the k8s tunnel)
#
# Each checks a health path with the service token so the request travels the whole
# path: Cloudflare edge, Access, tunnel, cloudflared, the Service, the Pod. Without
# the token Access would answer with a redirect at the edge and the monitor would
# stay green with the cluster switched off. See
# cloudflare_zero_trust_access_service_token.uptime for why the token is scoped to
# these two paths.
resource "betteruptime_monitor" "argocd" {
  url          = "https://argocd.m1sk9.dev/healthz"
  monitor_type = "status"

  request_headers = [
    {
      name  = "CF-Access-Client-Id"
      value = cloudflare_zero_trust_access_service_token.uptime.client_id
    },
    {
      name  = "CF-Access-Client-Secret"
      value = cloudflare_zero_trust_access_service_token.uptime.client_secret
    },
  ]

  check_frequency     = local.monitor_check_frequency
  regions             = local.monitor_regions
  request_timeout     = local.monitor_request_timeout
  confirmation_period = local.monitor_confirmation_period
  recovery_period     = local.monitor_recovery_period

  email = true
}

resource "betteruptime_monitor" "grafana" {
  url          = "https://grafana.m1sk9.dev/api/health"
  monitor_type = "status"

  request_headers = [
    {
      name  = "CF-Access-Client-Id"
      value = cloudflare_zero_trust_access_service_token.uptime.client_id
    },
    {
      name  = "CF-Access-Client-Secret"
      value = cloudflare_zero_trust_access_service_token.uptime.client_secret
    },
  ]

  check_frequency     = local.monitor_check_frequency
  regions             = local.monitor_regions
  request_timeout     = local.monitor_request_timeout
  confirmation_period = local.monitor_confirmation_period
  recovery_period     = local.monitor_recovery_period

  email = true
}
