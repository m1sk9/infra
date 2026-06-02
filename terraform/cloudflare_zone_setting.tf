# Cloudflare Zone SSL/TLS settings.
#
# In provider v5 each zone setting is its own cloudflare_zone_setting resource
# (the v4 cloudflare_zone_settings_override block no longer exists).

# Edge-to-origin encryption mode.
# "full" rather than "strict" so the edge keeps serving even if the GitHub Pages
# certificate renewal stalls. Never "flexible" — it causes a redirect loop with
# GitHub Pages.
resource "cloudflare_zone_setting" "ssl" {
  zone_id    = local.cloudflare_zone_id
  setting_id = "ssl"
  value      = "full"
}

# Redirect every HTTP request to HTTPS at the edge.
resource "cloudflare_zone_setting" "always_use_https" {
  zone_id    = local.cloudflare_zone_id
  setting_id = "always_use_https"
  value      = "on"
}

# Rewrite insecure http:// references to https:// in served content.
resource "cloudflare_zone_setting" "automatic_https_rewrites" {
  zone_id    = local.cloudflare_zone_id
  setting_id = "automatic_https_rewrites"
  value      = "on"
}

# Reject TLS handshakes negotiated below TLS 1.2.
resource "cloudflare_zone_setting" "min_tls_version" {
  zone_id    = local.cloudflare_zone_id
  setting_id = "min_tls_version"
  value      = "1.2"
}

# HSTS (Strict-Transport-Security). Reversible-risk: browsers enforce HTTPS for
# max_age seconds, so a certificate outage locks clients out. Introduced
# conservatively and ramped up in later PRs:
#   - max_age 1 day to keep the lock-in window short while we confirm behaviour
#   - include_subdomains off so grey two-label subdomains (lc.api, babyrite.api)
#     are not forced to HTTPS by the apex header
#   - preload off (one-way once submitted)
# nosniff (X-Content-Type-Options) shares this object but is out of scope here.
resource "cloudflare_zone_setting" "security_header" {
  zone_id    = local.cloudflare_zone_id
  setting_id = "security_header"
  value = {
    strict_transport_security = {
      enabled            = true
      include_subdomains = false
      max_age            = 86400
      nosniff            = false
      preload            = false
    }
  }
}
