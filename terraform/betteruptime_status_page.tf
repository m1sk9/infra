# Better Stack status page (status.m1sk9.dev)

# Why the status page is hosted by Better Stack rather than rendered by a Worker:
# every monitored target sits behind Cloudflare, so a Cloudflare outage is
# precisely the moment this page matters. Serving it from Workers would take it
# down together with everything it reports on.
#
# Design is limited to what the free plan allows. custom_css and
# custom_javascript exist as attributes but are billed at $15/page/month, and
# whitelabeled (dropping the "Powered by Better Stack" footer) at $250, so the
# look is whatever design/theme/layout can express.
resource "betteruptime_status_page" "m1sk9" {
  company_name = "m1sk9"
  company_url  = "https://m1sk9.dev"

  # Required even with a custom domain, and unique across all of Better Stack —
  # the page stays reachable at <subdomain>.betteruptime.com as well.
  subdomain = "m1sk9"

  # Rails TimeZone name, not an IANA one (contrast
  # betteruptime_heartbeat.backup.server_timezone).
  timezone = "Tokyo"

  custom_domain = "status.m1sk9.dev"
  published     = true

  design = "v2" # theme, layout and navigation_links require the modern design
  theme  = "dark"
  layout = "vertical"

  history = 90

  # Checks run every 3 minutes, so anything shorter than this is a single failed
  # probe rather than an outage worth publishing.
  min_incident_length = 300

  hide_from_search_engines = true
  subscribable             = true

  navigation_links {
    text = "m1sk9.dev"
    href = "https://m1sk9.dev"
  }

  # The custom domain is verified against the CNAME on creation, so the record
  # has to exist first.
  depends_on = [cloudflare_dns_record.status_page]
}

# --- Sections ---

resource "betteruptime_status_page_section" "server" {
  status_page_id = betteruptime_status_page.m1sk9.id
  name           = "Server (s1)"
  position       = 0
}

resource "betteruptime_status_page_section" "web" {
  status_page_id = betteruptime_status_page.m1sk9.id
  name           = "Web"
  position       = 1
}

resource "betteruptime_status_page_section" "self_hosted" {
  status_page_id = betteruptime_status_page.m1sk9.id
  name           = "Self-hosted"
  position       = 2
}

# --- Server (s1) ---

resource "betteruptime_status_page_resource" "s1_host" {
  status_page_id         = betteruptime_status_page.m1sk9.id
  status_page_section_id = betteruptime_status_page_section.server.id
  resource_id            = betteruptime_heartbeat.s1_host.id
  resource_type          = "Heartbeat"
  public_name            = "s1"
  explanation            = "The host pushes a heartbeat every 2 minutes. Reported down when the pushes stop, which includes the home line going out."
  widget_type            = "history"
  position               = 0
}

resource "betteruptime_status_page_resource" "backup" {
  status_page_id         = betteruptime_status_page.m1sk9.id
  status_page_section_id = betteruptime_status_page_section.server.id
  resource_id            = betteruptime_heartbeat.backup.id
  resource_type          = "Heartbeat"
  public_name            = "s1-backup"
  explanation            = "Weekly restic backup to Cloudflare R2, Friday 03:00 JST."
  widget_type            = "history"
  position               = 1
}

# --- Web ---

resource "betteruptime_status_page_resource" "portfolio" {
  status_page_id         = betteruptime_status_page.m1sk9.id
  status_page_section_id = betteruptime_status_page_section.web.id
  resource_id            = betteruptime_monitor.portfolio.id
  resource_type          = "Monitor"
  public_name            = "m1sk9.dev"
  widget_type            = "response_times"
  position               = 0
}

resource "betteruptime_status_page_resource" "books" {
  status_page_id         = betteruptime_status_page.m1sk9.id
  status_page_section_id = betteruptime_status_page_section.web.id
  resource_id            = betteruptime_monitor.books.id
  resource_type          = "Monitor"
  public_name            = "books.m1sk9.dev"
  explanation            = "Checked end to end through Cloudflare Access and the tunnel to the container."
  widget_type            = "response_times"
  position               = 1
}

# widget_type is history rather than response_times on purpose: the response time
# here is Cloudflare answering with the Access redirect, which says nothing about
# the origin and would read as a suspiciously fast service.
resource "betteruptime_status_page_resource" "wallos_edge" {
  status_page_id         = betteruptime_status_page.m1sk9.id
  status_page_section_id = betteruptime_status_page_section.web.id
  resource_id            = betteruptime_monitor.wallos_edge.id
  resource_type          = "Monitor"
  public_name            = "wallos.m1sk9.dev"
  explanation            = "Edge reachability only — confirms DNS, Cloudflare and Access. The container itself is covered by wallos under Self-hosted."
  widget_type            = "history"
  position               = 2
}

# --- Self-hosted ---

resource "betteruptime_status_page_resource" "wallos" {
  status_page_id         = betteruptime_status_page.m1sk9.id
  status_page_section_id = betteruptime_status_page_section.self_hosted.id
  resource_id            = betteruptime_heartbeat.wallos.id
  resource_type          = "Heartbeat"
  public_name            = "wallos"
  explanation            = "Probed on s1 itself, so this covers the tunnel and the container behind wallos.m1sk9.dev."
  widget_type            = "history"
  position               = 0
}

resource "betteruptime_status_page_resource" "chime" {
  status_page_id         = betteruptime_status_page.m1sk9.id
  status_page_section_id = betteruptime_status_page_section.self_hosted.id
  resource_id            = betteruptime_heartbeat.chime.id
  resource_type          = "Heartbeat"
  public_name            = "chime"
  explanation            = "Reports its own liveness check, which fails once the scheduler stops ticking."
  widget_type            = "history"
  position               = 1
}

resource "betteruptime_status_page_resource" "babyrite" {
  status_page_id         = betteruptime_status_page.m1sk9.id
  status_page_section_id = betteruptime_status_page_section.self_hosted.id
  resource_id            = betteruptime_heartbeat.babyrite.id
  resource_type          = "Heartbeat"
  public_name            = "babyrite"
  explanation            = "Container liveness only — a dropped Discord gateway connection is not visible here."
  widget_type            = "history"
  position               = 2
}

resource "betteruptime_status_page_resource" "honeypot" {
  status_page_id         = betteruptime_status_page.m1sk9.id
  status_page_section_id = betteruptime_status_page_section.self_hosted.id
  resource_id            = betteruptime_heartbeat.honeypot.id
  resource_type          = "Heartbeat"
  public_name            = "honeypot"
  explanation            = "Container liveness only — a dropped Discord gateway connection is not visible here."
  widget_type            = "history"
  position               = 3
}
