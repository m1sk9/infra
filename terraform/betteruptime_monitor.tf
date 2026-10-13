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
