# Managed Cloudflare DNS records.

# --- CNAME Records ---

# Portfolio (rollback target — the portfolio itself is served by Workers)
#
# Why keep a record that nothing resolves to in practice: the apex is claimed by
# cloudflare_workers_route.portfolio, so requests are answered by the Worker and
# GitHub Pages is never fetched. This record stays as the rollback path — delete
# the route and the apex falls straight back to Pages with no DNS change. It is
# also what the route attaches to: the route needs a proxied record on the
# hostname to sit in front of.
#
# Note that the Pages certificate for this origin is expired, so it is only a
# usable fallback while the zone runs SSL/TLS mode Full (non-strict).
resource "cloudflare_dns_record" "portfolio" {
  zone_id = local.cloudflare_zone_id
  name    = "m1sk9.dev"
  content = "m1sk9.github.io"
  type    = "CNAME"
  ttl     = 1
  proxied = true
  comment = "portfolio"
}

# babyrite API Documentation (GitHub Pages)
resource "cloudflare_dns_record" "babyrite_api_docs" {
  zone_id = local.cloudflare_zone_id
  name    = "babyrite.api"
  content = "m1sk9.github.io"
  type    = "CNAME"
  ttl     = 1
  proxied = false
  comment = "babyrite API Documentation"
}

# LunaticChat API Docs (GitHub Pages)
resource "cloudflare_dns_record" "lc_api_docs" {
  zone_id = local.cloudflare_zone_id
  name    = "lc.api"
  content = "m1sk9.github.io"
  type    = "CNAME"
  ttl     = 1
  proxied = false
  comment = "LunaticChat API Docs"
}

# HoneyPot (GitHub Pages)
resource "cloudflare_dns_record" "honeypot_api" {
  zone_id = local.cloudflare_zone_id
  name    = "honeypot.api"
  content = "m1sk9.github.io"
  type    = "CNAME"
  ttl     = 1
  proxied = false
  comment = "HoneyPot"
}

# Better Stack status page (status.m1sk9.dev)
#
# Why proxied = false: Better Stack terminates TLS on statuspage.betteruptime.com
# and issues its own certificate for this hostname, so the record has to stay
# DNS-only — proxying it would break HTTPS. This is a 1-level subdomain, so the
# 2-level Universal SSL limitation that rules out proxying lc.api / babyrite.api
# is not what is at play here.
resource "cloudflare_dns_record" "status_page" {
  zone_id = local.cloudflare_zone_id
  name    = "status"
  content = "statuspage.betteruptime.com"
  type    = "CNAME"
  ttl     = 1
  proxied = false
  comment = "Better Stack status page"
}

# Proton Mail DKIM
resource "cloudflare_dns_record" "protonmail_dkim1" {
  zone_id = local.cloudflare_zone_id
  name    = "protonmail._domainkey"
  content = "protonmail.domainkey.dboodxruenjy74fydrtqvoctqddo52zbjg2ddaglpacpjrmfm6bbq.domains.proton.ch"
  type    = "CNAME"
  ttl     = 1
  proxied = false
  comment = "Proton Mail"
}

resource "cloudflare_dns_record" "protonmail_dkim2" {
  zone_id = local.cloudflare_zone_id
  name    = "protonmail2._domainkey"
  content = "protonmail2.domainkey.dboodxruenjy74fydrtqvoctqddo52zbjg2ddaglpacpjrmfm6bbq.domains.proton.ch"
  type    = "CNAME"
  ttl     = 1
  proxied = false
  comment = "Proton Mail"
}

resource "cloudflare_dns_record" "protonmail_dkim3" {
  zone_id = local.cloudflare_zone_id
  name    = "protonmail3._domainkey"
  content = "protonmail3.domainkey.dboodxruenjy74fydrtqvoctqddo52zbjg2ddaglpacpjrmfm6bbq.domains.proton.ch"
  type    = "CNAME"
  ttl     = 1
  proxied = false
  comment = "Proton Mail"
}

# --- MX Records ---

# Proton Mail
resource "cloudflare_dns_record" "protonmail_mx1" {
  zone_id  = local.cloudflare_zone_id
  name     = "m1sk9.dev"
  content  = "mail.protonmail.ch"
  type     = "MX"
  ttl      = 1
  priority = 10
  comment  = "Proton Mail"
}

resource "cloudflare_dns_record" "protonmail_mx2" {
  zone_id  = local.cloudflare_zone_id
  name     = "m1sk9.dev"
  content  = "mailsec.protonmail.ch"
  type     = "MX"
  ttl      = 1
  priority = 20
  comment  = "Proton Mail"
}

# --- TXT Records ---

# GitHub Pages verification
resource "cloudflare_dns_record" "github_pages" {
  zone_id = local.cloudflare_zone_id
  name    = "_github-pages-challenge-m1sk9"
  content = "4a144ed0e9518a6efc3b5f80677bc5"
  type    = "TXT"
  ttl     = 1
}

# Bluesky verification
resource "cloudflare_dns_record" "bluesky" {
  zone_id = local.cloudflare_zone_id
  name    = "_atproto"
  content = "did=did:plc:x3z7xhecgb6575bx5b6kpak6"
  type    = "TXT"
  ttl     = 1
  comment = "Bluesky"
}

# Discord verification
resource "cloudflare_dns_record" "discord" {
  zone_id = local.cloudflare_zone_id
  name    = "_discord"
  content = "dh=0a6053d771fb057ccf2562e009f3a6e8d3121641"
  type    = "TXT"
  ttl     = 1
  comment = "Discord"
}

# DMARC
resource "cloudflare_dns_record" "dmarc" {
  zone_id = local.cloudflare_zone_id
  name    = "_dmarc"
  content = "v=DMARC1; p=quarantine"
  type    = "TXT"
  ttl     = 1
}

# Proton Mail verification
resource "cloudflare_dns_record" "protonmail_verification" {
  zone_id = local.cloudflare_zone_id
  name    = "m1sk9.dev"
  content = "protonmail-verification=6b5ba4a3a31f2e64a7aea6979b3a6fde8f9b56d6"
  type    = "TXT"
  ttl     = 1
  comment = "Proton Mail"
}

# Proton Mail SPF
resource "cloudflare_dns_record" "protonmail_spf" {
  zone_id = local.cloudflare_zone_id
  name    = "m1sk9.dev"
  content = "v=spf1 include:_spf.protonmail.ch ~all"
  type    = "TXT"
  ttl     = 1
  comment = "Proton Mail"
}
