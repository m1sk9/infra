# Managed Cloudflare DNS records.

# GitHub Pages verification record ---
resource "cloudflare_record" "github_pages" {
  zone_id = local.cloudflare_zone_id
  name    = "_github-pages-challenge-m1sk9"
  content = "4a144ed0e9518a6efc3b5f80677bc5"
  type    = "TXT"
  ttl     = 1
}
