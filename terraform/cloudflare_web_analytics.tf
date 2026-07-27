# Cloudflare Web Analytics for the portfolio (m1sk9.dev).
#
# Privacy-friendly, cookieless analytics. The apex stays proxied, but the response
# now comes from a Worker serving the Zola build as static assets rather than from
# GitHub Pages (see cloudflare_workers_route.portfolio), so auto_install lets the
# edge inject the analytics beacon automatically — no change is needed in the Zola
# site itself.
#
# Why not inject the beacon from the Zola template instead: keeping it at the edge
# means the token lives only in Terraform. If edge injection turns out not to apply
# to Worker-generated responses, switch to auto_install = false and inject in the
# template — never both, or page views are counted twice.
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
