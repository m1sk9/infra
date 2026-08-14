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

# R2 bucket for Ledger's Discord chat archive (github.com/m1sk9/Ledger).
#
# Ledger exports Discord chat history as NDJSON, one line per message, plus a
# manifest.json describing which channels and time ranges have been archived.
# The viewer on ledger.m1sk9.dev reads both straight out of this bucket through
# a Worker's R2 binding, so the bucket is the storage layer and the source of
# truth for the site — there is no database behind it.
#
# Why the bucket stays private: the archive is a copy of a private Discord
# server's history, so it must never be reachable object-by-object. No managed
# r2.dev domain and no custom domain is attached here; the only reader is the
# Worker, which is what applies access control before returning anything.
#
# The Worker itself is not here for the same reason the portfolio's is not (see
# cloudflare_worker.tf): the script is a build artifact of the Ledger
# repository, deployed by wrangler. Terraform owns the bucket and the routing,
# wrangler owns the script and its R2 binding.
resource "cloudflare_r2_bucket" "ledger_archive" {
  account_id = local.cloudflare_account_id
  name       = "ledger-archive"
  location   = "apac"
}
