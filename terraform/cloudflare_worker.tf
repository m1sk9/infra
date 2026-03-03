# Cloudflare Workers

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

# lc.m1sk9.dev - LunaticChat VitePress documentation (assets deployed via CI/CD)
resource "cloudflare_workers_script" "lc" {
  account_id         = local.cloudflare_account_id
  script_name        = "lunaticchat-docs"
  content_file       = "${path.module}/workers/lc.js"
  content_sha256     = filesha256("${path.module}/workers/lc.js")
  main_module        = "lc.js"
  compatibility_date = "2024-09-23"

  lifecycle {
    ignore_changes = [content, content_file, content_sha256, compatibility_date, compatibility_flags, bindings]
  }
}

resource "cloudflare_workers_custom_domain" "lc" {
  account_id = local.cloudflare_account_id
  zone_id    = local.cloudflare_zone_id
  hostname   = "lc.m1sk9.dev"
  service    = cloudflare_workers_script.lc.script_name
}
