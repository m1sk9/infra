# Cloudflare WAF custom rules (zone entrypoint of http_request_firewall_custom).
#
# Why every custom rule lives in this one resource: the phase has a single zone
# entrypoint ruleset, so a second cloudflare_ruleset for the same phase would
# fight this one over the same object.

resource "cloudflare_ruleset" "waf_custom" {
  zone_id     = local.cloudflare_zone_id
  name        = "default"
  description = "Zone-level WAF custom rules"
  kind        = "zone"
  phase       = "http_request_firewall_custom"

  rules = [
    {
      ref         = "block_php"
      description = "Block .php requests (nothing here runs PHP except Wallos)"
      # Why not rely on Bot Fight Mode: it only challenges what it scores as a
      # bot, and a plain client asking for /x.php still reaches the Worker.
      # Why wallos.m1sk9.dev is excluded: Wallos is a PHP application
      # (login.php, settings.php, ...) behind Access, so a zone-wide match would
      # lock us out of it.
      expression = "(http.request.uri.path.extension eq \"php\" and http.host ne \"wallos.m1sk9.dev\")"
      action     = "block"
      enabled    = true
    },
  ]
}
