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

# m1sk9.dev - portfolio (served by a Worker, no origin behind it)
#
# Why this is the only HTTP monitor: everything else on s1 is Access-protected
# or has no health endpoint, so the heartbeats cover it from the inside. This
# one exists so that ssl_expiration still has a monitor to live on.
#
# Why domain_expiration is absent rather than set: Better Stack scopes it to
# the domain, not the monitor, and the provider reads it back as null some time
# after each apply, so unrelated plans keep picking up a `-1 -> 30` change
# (2026-08-15, 2026-09-12). The provider only sends the field when it changes,
# so leaving it out of the configuration is what stops the churn. It is set in
# the UI instead, under the monitor's Advanced settings.
#
# ssl_expiration stays: it really is per-monitor and it holds the value.
resource "betteruptime_monitor" "portfolio" {
  url          = "https://m1sk9.dev"
  monitor_type = "status"

  check_frequency     = local.monitor_check_frequency
  regions             = local.monitor_regions
  request_timeout     = local.monitor_request_timeout
  confirmation_period = local.monitor_confirmation_period
  recovery_period     = local.monitor_recovery_period

  email          = true
  ssl_expiration = 30
}
