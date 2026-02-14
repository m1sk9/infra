locals {
  # AccountID and ZoneID are not secret and can be hard-coded.
  # https://github.com/cloudflare/wrangler-legacy/issues/209#issuecomment-541654484
  cloudflare_account_id = "c583c7c70623bd9136c2c7237b80ff54"
  cloudflare_zone_id    = "279a766b433692abdbde9bdce86ac7ab"
}
