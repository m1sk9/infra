# Better Stack status page (status.m1sk9.dev)

# Why the status page is hosted by Better Stack rather than rendered by a Worker:
# every monitored target sits behind Cloudflare, so a Cloudflare outage is
# precisely the moment this page matters. Serving it from Workers would take it
# down together with everything it reports on.
#
# What this resource deliberately does not set, and why:
#
# The free plan refuses API writes to anything the dashboard files under
# "Advanced settings" — "Cannot modify status page advanced settings. Please
# upgrade your account to modify advanced status page settings." Some of those
# are billed features (custom_css and custom_javascript at $15/page/month,
# whitelabeled / password_enabled / ip_allowlist / require_sso far above that),
# but others are free to set by hand and simply not reachable through the API:
# history, min_incident_length, hide_from_search_engines, navigation_links and
# even published. Those are configured in the dashboard — including flipping the
# page to published, which is why this resource cannot do it. Leaving them out of
# the configuration means Terraform does not diff against them, so the manual
# values survive. subscribable is billed, so it stays off entirely.
#
# Everything below sits outside that section and applies cleanly: the identity
# fields, the whole Personalization block (design / theme / layout) and — despite
# what the pricing page's "Custom sub-domain" wording suggests — the custom
# domain.
resource "betteruptime_status_page" "m1sk9" {
  # Better Stack renders this as "<company_name> status", so it holds the name
  # alone. Putting the hostname here reads as "status.m1sk9.dev status".
  company_name = "m1sk9's infra"
  company_url  = "https://m1sk9.dev"

  # Required even with a custom domain, and unique across all of Better Stack —
  # the page stays reachable at <subdomain>.betteruptime.com as well.
  subdomain = "m1sk9"

  # Rails TimeZone name, not an IANA one (contrast
  # betteruptime_heartbeat.backup.server_timezone).
  timezone = "Tokyo"

  custom_domain = "status.m1sk9.dev"

  design = "v2" # theme and layout require the modern design
  theme  = "dark"
  layout = "vertical"

  # The custom domain is verified against the CNAME on creation, so the record
  # has to exist first.
  depends_on = [cloudflare_dns_record.status_page]
}

# --- Sections ---
#
# The two hosts sit at the top level without a section, so the page opens with
# them. Positions are shared by loose resources and sections: s1 and s2 come first,
# then the sections.

resource "betteruptime_status_page_section" "infra" {
  status_page_id = betteruptime_status_page.m1sk9.id
  name           = "Infra"
  position       = 2
}

resource "betteruptime_status_page_section" "discord_bot" {
  status_page_id = betteruptime_status_page.m1sk9.id
  name           = "Discord Bot"
  position       = 3
}

# --- Hosts ---

# Not named s1_host any more, so that Terraform replaces the old entry rather than
# trying to move it out of the section it was in: the provider does not clear
# status_page_section_id when the attribute is dropped, and that section is deleted
# in the same apply.
resource "betteruptime_status_page_resource" "host_s1" {
  status_page_id = betteruptime_status_page.m1sk9.id
  resource_id    = betteruptime_heartbeat.s1_host.id
  resource_type  = "Heartbeat"
  public_name    = "s1"
  explanation    = "The host pushes a heartbeat every 2 minutes. Reported down when the pushes stop, which includes the home line going out."
  widget_type    = "history"
  position       = 0
}

resource "betteruptime_status_page_resource" "host_s2" {
  status_page_id = betteruptime_status_page.m1sk9.id
  resource_id    = betteruptime_heartbeat.s2_host.id
  resource_type  = "Heartbeat"
  public_name    = "s2"
  explanation    = "The k3s server pushes a heartbeat every 2 minutes. Reported down when the pushes stop, which includes the home line going out."
  widget_type    = "history"
  position       = 1
}

# --- Infra ---

resource "betteruptime_status_page_resource" "argocd" {
  status_page_id         = betteruptime_status_page.m1sk9.id
  status_page_section_id = betteruptime_status_page_section.infra.id
  resource_id            = betteruptime_monitor.argocd.id
  resource_type          = "Monitor"
  public_name            = "ArgoCD"
  explanation            = "Checked end to end through Cloudflare Access and the tunnel to the Pod."
  widget_type            = "response_times"
  position               = 0
}

resource "betteruptime_status_page_resource" "grafana" {
  status_page_id         = betteruptime_status_page.m1sk9.id
  status_page_section_id = betteruptime_status_page_section.infra.id
  resource_id            = betteruptime_monitor.grafana.id
  resource_type          = "Monitor"
  public_name            = "Grafana"
  explanation            = "Checked end to end through Cloudflare Access and the tunnel to the Pod."
  widget_type            = "response_times"
  position               = 1
}

# --- Discord Bot ---
#
# Each bot is reported by a push from s2, which checks that the Deployment has an
# available replica. For chime that includes its own health command; for the others
# it proves the Pod is running, and a dropped Discord gateway connection is not
# visible here.

resource "betteruptime_status_page_resource" "babyrite" {
  status_page_id         = betteruptime_status_page.m1sk9.id
  status_page_section_id = betteruptime_status_page_section.discord_bot.id
  resource_id            = betteruptime_heartbeat.babyrite.id
  resource_type          = "Heartbeat"
  public_name            = "babyrite"
  explanation            = "Pod availability only — a dropped Discord gateway connection is not visible here."
  widget_type            = "history"
  position               = 0
}

resource "betteruptime_status_page_resource" "pythia" {
  status_page_id         = betteruptime_status_page.m1sk9.id
  status_page_section_id = betteruptime_status_page_section.discord_bot.id
  resource_id            = betteruptime_heartbeat.pythia.id
  resource_type          = "Heartbeat"
  public_name            = "Pythia"
  explanation            = "Pod availability only — a dropped Discord gateway connection is not visible here."
  widget_type            = "history"
  position               = 1
}

resource "betteruptime_status_page_resource" "honeypot" {
  status_page_id         = betteruptime_status_page.m1sk9.id
  status_page_section_id = betteruptime_status_page_section.discord_bot.id
  resource_id            = betteruptime_heartbeat.honeypot.id
  resource_type          = "Heartbeat"
  public_name            = "Honeypot"
  explanation            = "Pod availability only — a dropped Discord gateway connection is not visible here."
  widget_type            = "history"
  position               = 2
}

resource "betteruptime_status_page_resource" "chime" {
  status_page_id         = betteruptime_status_page.m1sk9.id
  status_page_section_id = betteruptime_status_page_section.discord_bot.id
  resource_id            = betteruptime_heartbeat.chime.id
  resource_type          = "Heartbeat"
  public_name            = "chime"
  explanation            = "Reports its own health check, which fails once the scheduler stops ticking."
  widget_type            = "history"
  position               = 3
}
