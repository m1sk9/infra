# Cloudflare Bot Fight Mode and AI bot settings (Free plan).
#
# Every value mirrors what was set in the dashboard at import time, so adopting
# this resource changes nothing on the zone.
#
# Why Bot Fight Mode stays on although it was once deferred over Better Stack
# false positives: in the 30 days to 2026-10-08 none of the ~43,400 Better Stack
# checks (m1sk9.dev, books, wallos) were challenged or blocked.
#
# Why bot_preference_sync_enabled is not set: provider v5.27.0 never sends or
# reads it, so any apply that touches it fails with "inconsistent result after
# apply" (cloudflare/terraform-provider-cloudflare#7385).
#
# Why there are no sbfm_* attributes: Super Bot Fight Mode is not available on
# the Free plan.

import {
  to = cloudflare_bot_management.zone
  id = local.cloudflare_zone_id
}

resource "cloudflare_bot_management" "zone" {
  zone_id                 = local.cloudflare_zone_id
  fight_mode              = true
  enable_js               = true
  ai_bots_protection      = "disabled"
  crawler_protection      = "disabled"
  content_bots_protection = "disabled"
  ai_training             = "disabled"
  ai_user                 = "disabled"
  aisearch                = "disabled"
  is_robots_txt_managed   = false
  cf_robots_variant       = "policy_only"
}
