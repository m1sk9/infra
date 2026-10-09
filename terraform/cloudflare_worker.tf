# Cloudflare Workers

# m1sk9.dev - Portfolio (Zola static site served by Workers static assets)
#
# Why not a cloudflare_workers_script resource like the others below: the script
# and its assets are a per-commit Zola build artifact, deployed by wrangler from
# the m1sk9.dev repository. Terraform cannot own content it does not build, so
# `script` is a plain string literal instead of a resource reference and the
# ownership boundary is: wrangler owns the script, Terraform owns the routing.
#
# Why not a cloudflare_workers_custom_domain: a custom domain owns the hostname's
# DNS record itself, so adopting it would mean destroying and recreating the apex
# record — a downtime window on the way in, and a record to rebuild on the way
# out. A route attaches to the existing proxied record instead: the cutover and
# the rollback are a single route being added or removed, with the CNAME left
# untouched (see cloudflare_dns_record.portfolio).
#
# Why not a cloudflare_workers_script_subdomain resource: wrangler touches the
# workers.dev subdomain on every deploy, so Terraform would fight it on each
# run. The exposure is disabled on the wrangler side (`workers_dev = false`).
resource "cloudflare_workers_route" "portfolio" {
  zone_id = local.cloudflare_zone_id
  pattern = "m1sk9.dev/*"
  script  = "m1sk9-dev"
}

# blog.m1sk9.dev - Redirect to m1sk9.dev/posts/ with Mastodon rel="me"
resource "cloudflare_workers_script" "blog" {
  account_id         = local.cloudflare_account_id
  script_name        = "blog-redirect"
  content_file       = "${path.module}/workers/blog.js"
  content_sha256     = filesha256("${path.module}/workers/blog.js")
  main_module        = "blog.js"
  compatibility_date = "2024-09-23"
}

resource "cloudflare_workers_custom_domain" "blog" {
  account_id = local.cloudflare_account_id
  zone_id    = local.cloudflare_zone_id
  hostname   = "blog.m1sk9.dev"
  service    = cloudflare_workers_script.blog.script_name
}

# Custom domain only — disable the workers.dev subdomain exposure.
resource "cloudflare_workers_script_subdomain" "blog" {
  account_id       = local.cloudflare_account_id
  script_name      = cloudflare_workers_script.blog.script_name
  enabled          = false
  previews_enabled = false
}

# ua.m1sk9.dev - User-Agent echo service
resource "cloudflare_workers_script" "ua" {
  account_id         = local.cloudflare_account_id
  script_name        = "ua-echo"
  content_file       = "${path.module}/workers/ua.js"
  content_sha256     = filesha256("${path.module}/workers/ua.js")
  main_module        = "ua.js"
  compatibility_date = "2024-09-23"
}

resource "cloudflare_workers_custom_domain" "ua" {
  account_id = local.cloudflare_account_id
  zone_id    = local.cloudflare_zone_id
  hostname   = "ua.m1sk9.dev"
  service    = cloudflare_workers_script.ua.script_name
}

# Custom domain only — disable the workers.dev subdomain exposure.
resource "cloudflare_workers_script_subdomain" "ua" {
  account_id       = local.cloudflare_account_id
  script_name      = cloudflare_workers_script.ua.script_name
  enabled          = false
  previews_enabled = false
}

# working.m1sk9.dev - Work hours calculator
resource "cloudflare_workers_script" "working" {
  account_id         = local.cloudflare_account_id
  script_name        = "work-hours"
  content_file       = "${path.module}/workers/working.js"
  content_sha256     = filesha256("${path.module}/workers/working.js")
  main_module        = "working.js"
  compatibility_date = "2025-05-01"
}

resource "cloudflare_workers_custom_domain" "working" {
  account_id = local.cloudflare_account_id
  zone_id    = local.cloudflare_zone_id
  hostname   = "working.m1sk9.dev"
  service    = cloudflare_workers_script.working.script_name
}

# Custom domain only — disable the workers.dev subdomain exposure.
resource "cloudflare_workers_script_subdomain" "working" {
  account_id       = local.cloudflare_account_id
  script_name      = cloudflare_workers_script.working.script_name
  enabled          = false
  previews_enabled = false
}

# ledger.m1sk9.dev - Ledger's Discord chat archive viewer
#
# Why `service` is a string literal and not a cloudflare_workers_script
# reference: the script is a build artifact of the Ledger repository, deployed
# by wrangler, which reads the archive out of cloudflare_r2_bucket.ledger_archive
# through an R2 binding wrangler also owns. Same boundary as the portfolio above:
# wrangler owns the script, Terraform owns the routing.
#
# Why a custom domain and not a workers_route like the portfolio: a route needs
# an existing proxied record to attach to, and ledger.m1sk9.dev has none. With no
# record to adopt there is nothing to destroy and recreate, so the custom domain
# creates the hostname itself — the same shape as blog, ua and working.
#
# Why not a cloudflare_workers_script_subdomain like its neighbours: the exposure
# is already disabled on the wrangler side (`workers_dev: false` in Ledger's
# wrangler.jsonc). Since wrangler owns this script, Terraform holding the same
# setting would mean the two fighting over it on every deploy.
resource "cloudflare_workers_custom_domain" "ledger" {
  account_id = local.cloudflare_account_id
  zone_id    = local.cloudflare_zone_id
  hostname   = "ledger.m1sk9.dev"
  service    = "ledger-web"
}

# leak-alert - Discord alert when a secret-looking path is answered with 2xx
#
# Why HTTP requests rather than Firewall events: a leak is a request that got
# through, so it never appears among the mitigated events. The Worker reads
# httpRequestsAdaptiveGroups every 15 minutes and posts to Discord only when
# something like /.git/config or /.env returned 2xx outside the catch-all
# Workers (see the comment in workers/leak-alert.js).
#
# Why an API token instead of the Analytics SQL binding, which needs none: that
# binding is configured through wrangler only, and provider v5.27.0 has no
# binding type for it. The token is scoped to Zone Analytics Read on m1sk9.dev.
#
# No route or custom domain: the Worker has only a scheduled handler.
resource "cloudflare_workers_script" "leak_alert" {
  account_id         = local.cloudflare_account_id
  script_name        = "leak-alert"
  content_file       = "${path.module}/workers/leak-alert.js"
  content_sha256     = filesha256("${path.module}/workers/leak-alert.js")
  main_module        = "leak-alert.js"
  compatibility_date = "2026-10-01"

  bindings = [
    {
      name = "ZONE_TAG"
      type = "plain_text"
      text = local.cloudflare_zone_id
    },
    {
      name = "CF_ANALYTICS_TOKEN"
      type = "secret_text"
      text = var.leak_alert_cloudflare_api_token
    },
    {
      name = "DISCORD_WEBHOOK_URL"
      type = "secret_text"
      text = var.leak_alert_discord_webhook_url
    },
    {
      name = "HEARTBEAT_URL"
      type = "secret_text"
      text = betteruptime_heartbeat.leak_alert.url
    },
  ]
}

resource "cloudflare_workers_cron_trigger" "leak_alert" {
  account_id  = local.cloudflare_account_id
  script_name = cloudflare_workers_script.leak_alert.script_name
  schedules = [{
    cron = "*/15 * * * *"
  }]
}

# Scheduled only — disable the workers.dev subdomain exposure.
resource "cloudflare_workers_script_subdomain" "leak_alert" {
  account_id       = local.cloudflare_account_id
  script_name      = cloudflare_workers_script.leak_alert.script_name
  enabled          = false
  previews_enabled = false
}
