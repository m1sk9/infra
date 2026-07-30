# Better Stack monitors (external HTTP checks)

locals {
  # The free plan floor. Asking for less than this is rejected — 30s checks are
  # a paid feature.
  monitor_check_frequency = 180

  # Two regions so that a single unhealthy probe location does not read as an
  # outage. "as" is the closest to the origin, "us" is the control.
  monitor_regions = ["as", "us"]

  # Valid options for HTTP monitors are 2, 3, 5, 10, 15, 30, 45 and 60 seconds.
  # 10 is generous for Cloudflare-fronted hosts but s1 is a Celeron 3855U, so
  # the origin-backed checks need the headroom.
  monitor_request_timeout = 10

  # Wait one further check before opening or closing an incident, so a single
  # dropped request does not page.
  monitor_confirmation_period = 180
  monitor_recovery_period     = 180
}

# m1sk9.dev - Portfolio (Zola static site served by Workers)
#
# Why keyword rather than a bare 2xx check: the apex is answered by a Worker, and
# a Worker that has lost its assets or been deployed empty still returns 200. The
# title is the cheapest proof that the site actually rendered.
#
# This is the only monitor that checks domain expiration: every hostname here
# lives on m1sk9.dev, so enabling it everywhere would just mean three copies of
# the same warning.
resource "betteruptime_monitor" "portfolio" {
  url              = "https://m1sk9.dev"
  monitor_type     = "keyword"
  required_keyword = "Sho Sakuma"

  check_frequency     = local.monitor_check_frequency
  regions             = local.monitor_regions
  request_timeout     = local.monitor_request_timeout
  confirmation_period = local.monitor_confirmation_period
  recovery_period     = local.monitor_recovery_period

  email             = true
  ssl_expiration    = 30
  domain_expiration = 30
}

# books.m1sk9.dev - PdfDing (Access-protected, behind the s1 tunnel)
#
# Checks /healthz with the service token so the request travels the whole path:
# Cloudflare edge, Access, tunnel, container. Without the token Access would
# answer with a redirect at the edge and this monitor would stay green with the
# server switched off. See cloudflare_zero_trust_access_service_token.uptime for
# why the token is scoped to this one path.
resource "betteruptime_monitor" "books" {
  url          = "https://books.m1sk9.dev/healthz"
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

  email             = true
  ssl_expiration    = 30
  domain_expiration = -1
}

# wallos.m1sk9.dev - Wallos (Access-protected, edge reachability only)
#
# Why 302 is the expected result: Wallos has no health endpoint (its compose file
# disables the container healthcheck outright), so there is no safe path to scope
# a service token to the way books.m1sk9.dev has /healthz. Pointing a token at
# `/` would leave a standing credential for the subscription data, so this
# deliberately checks only that the edge still answers with the Access login
# redirect — DNS, Cloudflare and the Access configuration.
#
# That leaves the tunnel and the container unproven, which is what the
# betteruptime_heartbeat.wallos push from s1 covers. Neither half is sufficient
# alone: the redirect is served without ever consulting the origin, and the
# heartbeat cannot see a Cloudflare-side failure.
resource "betteruptime_monitor" "wallos_edge" {
  url                   = "https://wallos.m1sk9.dev"
  monitor_type          = "expected_status_code"
  expected_status_codes = [302]
  follow_redirects      = false

  # The API rejects the pair outright ("Cannot keep cookies when redirecting when
  # expecting a 3xx status code"): remembering cookies only means anything if the
  # redirect is followed, and here the redirect is the thing being asserted.
  remember_cookies = false

  check_frequency     = local.monitor_check_frequency
  regions             = local.monitor_regions
  request_timeout     = local.monitor_request_timeout
  confirmation_period = local.monitor_confirmation_period
  recovery_period     = local.monitor_recovery_period

  email             = true
  ssl_expiration    = 30
  domain_expiration = -1
}
