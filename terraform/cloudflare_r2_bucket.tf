# R2 bucket for s1's off-site backups (restic repository).
#
# s1 self-hosts data (currently wallos' SQLite DB and uploaded logos) that
# Ansible cannot regenerate. restic pushes an encrypted, deduplicated backup
# here weekly; R2 is S3-compatible so restic talks to it directly via its s3
# backend. Terraform state itself lives in HCP Terraform, not R2, so this
# bucket is created fresh here.
#
# restic authenticates with an R2 *S3 API token* (Access Key ID / Secret),
# which Cloudflare only issues from the dashboard — it cannot be provisioned by
# Terraform. Create it manually (Object Read & Write, scoped to this bucket)
# and store it in the Ansible vault.
resource "cloudflare_r2_bucket" "s1_backup" {
  account_id = local.cloudflare_account_id
  name       = "s1-backup"
  location   = "apac"
}
