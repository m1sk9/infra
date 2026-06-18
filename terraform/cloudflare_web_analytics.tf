# Cloudflare Web Analytics for the portfolio (m1sk9.dev).
#
# Privacy-friendly, cookieless analytics. The portfolio zone is orange-clouded
# (see cloudflare_dns_record.portfolio, proxied = true), so auto_install lets the
# edge inject the analytics beacon automatically — no change is needed in the
# Zola site itself.
#
# Requires the API token to carry Account Settings Read + Write.
resource "cloudflare_web_analytics_site" "portfolio" {
  account_id   = local.cloudflare_account_id
  zone_tag     = local.cloudflare_zone_id
  auto_install = true

  # Collect Real User Monitoring (Core Web Vitals: LCP, CLS, ...) on top of the
  # basic page-view metrics. Requires auto_install = true.
  enabled = true
}
