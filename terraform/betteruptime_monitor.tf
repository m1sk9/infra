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

  # Suppressed during s1's weekly maintenance reboot, scheduled by the Ansible
  # `scheduled_reboot` role — move one and the other has to move with it.
  #
  # Why this monitor alone needs the window: it is the only check that travels to
  # the container, so it is the only one the reboot can fail. wallos_edge is
  # answered by Cloudflare without consulting the origin, and every heartbeat
  # tolerates a missed run (the 2026-08-02 reboot left a 234 s gap in s1_host
  # against its 420 s budget, and 366 s in the service heartbeats against 600 s).
  #
  # The window is far wider than the outage it covers — 04:00:02 to 04:02:08 on
  # 2026-08-02 — because a forced fsck of the 865 GiB /home would stretch the boot
  # well past two minutes, and a window sized to the good case would leak an
  # incident the first time that happened. Nothing goes unwatched in the meantime:
  # betteruptime_heartbeat.s1_host has no maintenance window and still fails 420 s
  # after the pushes stop, so a reboot that never comes back is still reported.
  #
  # maintenance_timezone takes a Rails zone name, not an IANA one — "Tokyo", not
  # "Asia/Tokyo". Contrast server_timezone in betteruptime_heartbeat.tf.
  maintenance_from     = "04:00:00"
  maintenance_to       = "04:15:00"
  maintenance_days     = ["sun"]
  maintenance_timezone = "Tokyo"

  # domain_expiration is 30 on both monitors rather than disabled on one, because
  # Better Stack ignores -1 and keeps 30 anyway — asking for -1 just produces a
  # diff on every plan, forever. Both hostnames are on m1sk9.dev, so the
  # expiry warning arrives twice. Once a year, which is cheaper than permanent
  # plan noise.
  email             = true
  ssl_expiration    = 30
  domain_expiration = 30
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
#
# The same blindness is why this one carries no maintenance window for the weekly
# reboot: with the origin out of the picture there is nothing for the reboot to
# take down here. See books above.
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

  # See the note on books above for why this is 30 rather than -1.
  email             = true
  ssl_expiration    = 30
  domain_expiration = 30
}
