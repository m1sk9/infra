# R2 bucket for the restic repository shared by s1 and s2.
#
# One repository for both hosts, told apart by the host and tag on each snapshot,
# instead of a bucket per host: a bucket needs its own S3 API token from the
# dashboard, and the credentials in the vault are the same for both.
#
# restic authenticates with an R2 *S3 API token* (Access Key ID / Secret), which
# Cloudflare only issues from the dashboard — it cannot be provisioned by
# Terraform. Create it manually (Object Read & Write, scoped to this bucket) and
# store it in the Ansible vault.
resource "cloudflare_r2_bucket" "infra_backup" {
  account_id = local.cloudflare_account_id
  name       = "m1sk9-infra-backup"
  location   = "apac"
}
