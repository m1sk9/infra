# Ansible

Configuration management for the self-hosted servers. Secrets are protected with
[`ansible-vault`](https://docs.ansible.com/ansible/latest/vault_guide/index.html),
and hosts are reached over the Tailscale tailnet using their MagicDNS names.

## Prerequisites

- `ansible-core` is installed via [mise](https://mise.jdx.dev/) (see the repository root [`mise.toml`](../mise.toml)). Run `mise install` to set it up — mise uses `uv` as the backend for the `pipx:ansible-core` package.
- Install required collections: `ansible-galaxy collection install -r requirements.yml` (provides `community.docker`).
- The control machine must be connected to the Tailscale tailnet; hosts are only reachable from within it.
- The vault password file `ansible/.vault_pass` must exist locally (git-ignored). Without it, `ansible-vault`-encrypted variables cannot be decrypted.

## Layout

```
ansible/
├── ansible.cfg                      # inventory path, vault password file, SSH options
├── requirements.yml                 # Galaxy collections (community.docker)
├── inventory/
│   ├── hosts.yml                    # hosts and connection variables
│   └── group_vars/all/             # loaded relative to the inventory, so it applies
│       ├── vars.yml                 # non-sensitive variables; references vault_ secrets
│       └── vault.yml                # ansible-vault encrypted secrets
├── roles/
│   ├── docker_compose_app/          # generic "deploy a compose stack" role
│   │   ├── tasks/main.yml
│   │   ├── defaults/main.yml
│   │   └── files/<service>/         # compose.yaml + vault-encrypted env/config
│   ├── restic_backup/               # weekly restic backup to Cloudflare R2
│   ├── heartbeat/                   # Better Stack heartbeat senders (systemd timers)
│   └── scheduled_reboot/            # weekly maintenance reboot (systemd timer)
└── playbooks/
    ├── site.yml                     # connectivity check
    ├── services.yml                 # deploy all Docker Compose services
    ├── backup.yml                   # restic backup script and timer
    ├── monitoring.yml               # heartbeat senders
    └── maintenance.yml              # scheduled reboot
```

## Hosts

| Host | MagicDNS name   |
|------|-----------------|
| s1   | `dev-m1sk9-s1`  |

## Secrets (ansible-vault)

Secrets live in [`inventory/group_vars/all/vault.yml`](./inventory/group_vars/all/vault.yml),
encrypted with `ansible-vault`. Each secret uses a `vault_` prefix and is referenced from
[`inventory/group_vars/all/vars.yml`](./inventory/group_vars/all/vars.yml) so that playbooks
never read raw secret values directly.

The vault password is stored in `ansible/.vault_pass` (git-ignored). **Back it up
somewhere safe (e.g. a password manager) — without it the encrypted secrets are
unrecoverable.**

```fish
# Edit secrets
ansible-vault edit inventory/group_vars/all/vault.yml

# View secrets
ansible-vault view inventory/group_vars/all/vault.yml
```

`ansible.cfg` points `vault_password_file` at `.vault_pass`, so the regular `ansible`
and `ansible-playbook` commands decrypt secrets automatically.

## Usage

Run commands from within the `ansible/` directory (relative paths in `ansible.cfg` are
resolved against the current directory):

```fish
cd ansible

# Connectivity check
ansible-playbook playbooks/site.yml

# Dry-run before applying changes
ansible-playbook playbooks/site.yml --check --diff
```

## Services

Docker Compose services managed on s1. Each is deployed to `~/services/<name>/` by the
`docker_compose_app` role, with secrets stored vault-encrypted under
`roles/docker_compose_app/files/<service>/` and decrypted on deploy.

| Service | Image | Notes |
|---|---|---|
| babyrite | `ghcr.io/m1sk9/babyrite` | mounts `~/babyrite-data/config.toml`; `.env` |
| wallos | `ghcr.io/ellite/wallos` | published on `:8282`; data in `~/wallos-data` |
| pdfding | `mrmn/pdfding` | published on `:8384`; data in `~/pdfding-data/{db,media,consume}`; `.env` |
| hermes | `nousresearch/hermes-agent` | Discord-only chat bot; `~/hermes-data` is `/opt/data`; `.env`; toolsets restricted in `config.yaml` |

Deploy or update all services (idempotent — unchanged stacks are not recreated):

```fish
ansible-playbook playbooks/services.yml
```

### Adding a service

1. Create `roles/docker_compose_app/files/<name>/compose.yaml` with a top-level `name:`.
2. Encrypt any secrets: `ansible-vault encrypt roles/docker_compose_app/files/<name>/env`
3. Add a block to `playbooks/services.yml` setting `app_name`, and as needed `app_files`
   (env/config to copy) and `app_dirs` (host directories to create).

### Taildrive (PdfDing consume folder)

PdfDing's [consume folder](https://docs.pdfding.com/configuration/consumption/) watches
`~/pdfding-data/consume/<user-id>/` and imports any PDF placed there (deleting the
original afterwards, success or not). To make that folder reachable from other devices,
it's shared over [Taildrive](https://tailscale.com/kb/1369/taildrive) — this is a manual,
one-time step (mirroring how `tailscale up` itself is provisioned; see "Tailscale setup"
below), not something Ansible manages.

On s1, after the first PdfDing account has been created (the account's numeric id — `1`
for the first user — is the subfolder name):

```fish
mkdir -p ~/pdfding-data/consume/1
tailscale drive share pdfding_consume ~/pdfding-data/consume
tailscale drive list   # confirm the share is up
```

The share name is restricted to lowercase letters, `_`, `()`, and spaces (no hyphens or
digits). The `drive:share`/`drive:access` node attributes and the
`tailscale.com/cap/drive` grant needed to use this are already declared in
[`tailscale/policy.hujson`](../tailscale/policy.hujson).

From a Mac, mount it with [rclone](https://rclone.org/) (`brew install rclone`),
`~/.config/rclone/rclone.conf`:

```ini
[tsdrive]
type = webdav
url = http://100.100.100.100:8080/m1sk9.github
vendor = other
```

```fish
rclone copy ~/Downloads/book.pdf tsdrive:dev-m1sk9-s1/pdfding_consume/1/
```

Finder also works as a fallback (`Cmd+K` → `http://100.100.100.100:8080/m1sk9.github/dev-m1sk9-s1/pdfding_consume/`),
but its WebDAV client is less reliable for repeated transfers than rclone.

## Backups

s1's non-regenerable data is backed up weekly to a Cloudflare R2 bucket
(`s1-backup`) with [restic](https://restic.net/) — encrypted, deduplicated, and
versioned. The `restic_backup` role installs a pinned restic, renders a backup
script, and schedules it with a systemd timer (Friday 03:00). Deploy it with:

```fish
ansible-playbook playbooks/backup.yml
```

### What is backed up

Targets are declared in [`inventory/group_vars/all/vars.yml`](./inventory/group_vars/all/vars.yml)
as `backup_targets`; the role itself is data-agnostic. **To back up more data,
add an entry — no role changes needed:**

```yaml
backup_targets:
  - name: <tag>            # restic --tag identifying this target
    sqlite_dbs:            # optional: online-snapshotted with `sqlite3 .backup`
      - /path/to/foo.db
    paths:                 # optional: files/dirs handed to restic as-is
      - /path/to/assets
    excludes:              # optional: restic --exclude patterns
      - /path/to/assets/cache
```

Use `excludes` when naming the whole tree and carving out the regenerable parts
is more durable than listing the parts worth keeping — a service whose data
layout grows new directories across releases would otherwise stop being covered
without anyone noticing.

SQLite databases are snapshotted with `.backup` (consistent even while the
service writes) before restic reads them, so services need not be stopped.

### Required vault secrets

The R2 S3 API token (Object Read & Write, scoped to `s1-backup`) and the restic
repository password are **manually provisioned** — Terraform cannot issue R2 S3
tokens. Store them in the vault (`ansible-vault edit`):

| Vault key | Value |
|---|---|
| `vault_restic_password` | restic repository password (`openssl rand -base64 32`) |
| `vault_r2_access_key_id` | R2 S3 API token — Access Key ID |
| `vault_r2_secret_access_key` | R2 S3 API token — Secret Access Key |

Back these up in a password manager too — losing `vault_restic_password` makes
every backup unrecoverable.

### Restore

On s1, run restic with the deployed env file loaded (it holds the repository URL
and credentials). Wrap commands in a subshell that sources it:

```fish
# List snapshots for a target
sudo bash -c 'set -a; . /etc/restic/s1-backup.env; restic snapshots --tag wallos'

# Restore the latest wallos snapshot
sudo bash -c 'set -a; . /etc/restic/s1-backup.env; restic restore latest --tag wallos --target /tmp/restore'

# Verify the restored SQLite DB, then place it back and restart the service
sqlite3 /tmp/restore/.../wallos.db 'PRAGMA integrity_check;'
```

## Scheduled reboot

s1 is a repurposed laptop pressed into service as a always-on server, and it is
rebooted every **Sunday 04:00 JST** to stay stable across weeks of uptime. The
`scheduled_reboot` role owns that schedule (`s1-reboot.timer` →
`s1-reboot.service` → `systemctl reboot`). Deploy it with:

```fish
ansible-playbook playbooks/maintenance.yml
```

**This is deliberate maintenance, not housekeeping — do not remove it without a
replacement.** It was a hand-made unit on the host (`reboot-daily.timer`, named
"daily" while firing weekly) until it was brought in here; the role deletes those
files so the reboot cannot be scheduled from two places.

Applying the role never reboots s1. Starting a `.timer` arms the schedule without
running its `.service`, and the timer sets `Persistent=false`, so a window missed
while s1 was down is not caught up on the next boot — a host that just booted has
none of the accumulated state this reboot exists to clear.

Every service comes back on its own: `systemctl reboot` stops `docker.service`
through the normal shutdown transaction, and each stack is declared
`restart: unless-stopped`. Measured on 2026-08-02, the whole cycle took just over
two minutes end to end (reboot at 04:00:02, PdfDing serving again at 04:02:08).

### The reboot and the monitors

That two-minute gap is long enough for `betteruptime_monitor.books` to open an
incident, because `/healthz` is the one external check that travels all the way to
a container. It carries a matching **maintenance window (Sunday 04:00–04:15
Tokyo)** in [`terraform/betteruptime_monitor.tf`](../terraform/betteruptime_monitor.tf)
— **change `reboot_oncalendar` and that window has to move with it**, or the
status page reports a failure every week for a reboot working as intended.

Nothing else needs one. `wallos_edge` is answered by Cloudflare without consulting
the origin, and the heartbeats each tolerate a missed run — the same reboot left a
234 s gap in `s1_host` against its 420 s budget and 366 s in the service
heartbeats against 600 s. `s1_host` is deliberately left without a window, so a
reboot that fails to come back is still reported.

## Monitoring

s1 is reachable only over Cloudflare Tunnel and Tailscale, so nothing outside can
poll it. Every check that needs to see the host is inverted: the `heartbeat` role
installs systemd timers that push to [Better Stack](https://betterstack.com),
which raises an incident when the pushes stop. The monitors, heartbeats and the
status page at [status.m1sk9.dev](https://status.m1sk9.dev) are defined in
Terraform (`terraform/betteruptime_*.tf`). Deploy the senders with:

```fish
ansible-playbook playbooks/monitoring.yml
```

### What is monitored from s1

Targets are declared in [`inventory/group_vars/all/vars.yml`](./inventory/group_vars/all/vars.yml)
as `heartbeat_targets`; the role itself is data-agnostic. **To monitor another
service, add an entry and a matching `betteruptime_heartbeat` resource:**

```yaml
heartbeat_targets:
  - name: <unit name>      # used for the unit, script and env file names
    url: "{{ vault_heartbeat_url_<name> }}"
    oncalendar: "*:0/3"    # systemd schedule
    check_command: "..."   # optional; non-zero exit reports to <url>/fail
```

Omitting `check_command` makes the ping itself the signal, which is what the host
heartbeat does. Note that this measures "s1 can reach the internet", not "s1 is
powered on" — a home line outage raises the incident with the machine healthy.

`check_command` uses `docker ps --filter` rather than `docker inspect --format`
because the Go template in `--format` collides with Jinja2, and the filters ask
the same question without template syntax.

**How much each check actually proves differs:**

| Target | Proves |
|---|---|
| `wallos` | The container answers on localhost — the other half of the edge check in `betteruptime_monitor.wallos_edge` |
| `chime` | The scheduler is still ticking (its healthcheck fails once its heartbeat file goes stale) |
| `babyrite`, `honeypot`, `hermes` | Only that the container runs. All three hold Discord gateway websockets, so **a dead gateway inside a live process stays invisible** until those bots push for themselves |

### Backup notification

`restic_backup` reports through a heartbeat of its own, so a broken backup no
longer fails silently. Three cases are covered:

- **Success** — `ExecStartPost` pings the heartbeat, refreshing the weekly period
- **Failure** — `OnFailure=s1-backup-failure.service` posts the last 50 journal
  lines to `<url>/fail` immediately, rather than waiting a week for the period to
  lapse
- **Never ran** (s1 down at the scheduled time) — the period lapses

Setting `backup_heartbeat_url` to an empty string removes both units, so the role
still works without Better Stack.

### Required vault secrets

Heartbeat ping URLs are issued by Terraform and consumed here, but Ansible cannot
read Terraform state, so they are copied over by hand — the same arrangement as
the R2 credentials. **The URL is the only credential involved: anyone holding it
can report the service as healthy**, so treat it as a secret.

```fish
cd ../terraform
terraform output -raw heartbeat_url_s1_host   # repeat per key below
cd ../ansible && ansible-vault edit inventory/group_vars/all/vault.yml
```

| Vault key | Terraform output |
|---|---|
| `vault_heartbeat_url_s1_host` | `heartbeat_url_s1_host` |
| `vault_heartbeat_url_wallos` | `heartbeat_url_wallos` |
| `vault_heartbeat_url_chime` | `heartbeat_url_chime` |
| `vault_heartbeat_url_babyrite` | `heartbeat_url_babyrite` |
| `vault_heartbeat_url_honeypot` | `heartbeat_url_honeypot` |
| `vault_heartbeat_url_hermes` | `heartbeat_url_hermes` |
| `vault_heartbeat_url_backup` | `heartbeat_url_backup` |

These change only when a heartbeat resource is replaced, so this is a one-off per
heartbeat.

### Settings that live in the dashboard

Better Stack's free plan refuses API writes to anything the dashboard files under
**Advanced settings**, so those are set by hand and deliberately left out of the
Terraform configuration (which keeps Terraform from diffing against them):

| Dashboard setting | Value |
|---|---|
| Status history → How many days to display? | 90 days |
| Look & feel → Minimum incident length | above 0, so single failed probes stay hidden |
| Search engines → Hide from search engines | enabled |
| Replace top navigation links | link back to m1sk9.dev |
| **Status page access → Published** | **enabled — the page is not public otherwise** |

Design (modern look, dark theme, vertical layout) and the custom domain *are*
managed in Terraform: those sit outside that section.

## CI / CD

GitHub Actions deploys this configuration automatically, mirroring the Terraform setup.

- **CI** ([`ci.yaml`](../.github/workflows/ci.yaml)) — on every pull request:
  runs `--syntax-check` on all playbooks, then a **plan**
  (`--check --diff` for `services.yml`, `backup.yml`, `monitoring.yml` and
  `maintenance.yml`) against s1 so the PR shows exactly what would change — the
  Terraform `plan` equivalent. The `docker_compose_v2` module supports check mode,
  so the diff is meaningful.
- **CD** ([`cd.yaml`](../.github/workflows/cd.yaml)) — on push to `main`
  (or manual `workflow_dispatch`): joins the tailnet, then runs `services.yml`,
  `backup.yml`, `monitoring.yml` and `maintenance.yml` against s1.

Both workflows run their full job set on every PR and push — there is no
`paths`-based gating, so an Ansible-only change still runs the Terraform jobs and
vice versa.

Because s1 only exists inside the tailnet, the runner joins it as an ephemeral node via
the [Tailscale GitHub Action](https://tailscale.com/kb/1276/tailscale-github-action) and
connects to s1 over **Tailscale SSH** — no long-lived CI key is stored in GitHub.
Authentication is handled by Tailscale (the runner's `tag:ci` identity must be allowed
to SSH to s1 by the ACL, and s1 must have `tailscale up --ssh` enabled).

### Required GitHub secrets

| Secret | Purpose |
|---|---|
| `ANSIBLE_VAULT_PASSWORD` | decrypts the vault files |
| `TS_OAUTH_CLIENT_ID` | Tailscale OAuth client id |
| `TS_OAUTH_SECRET` | Tailscale OAuth client secret |

### Tailscale setup (one-time)

1. In the Tailscale admin console, create an **OAuth client** with the `auth_keys` scope,
   owning the tag `tag:ci`.
2. Register its id / secret as the `TS_OAUTH_*` secrets above.
3. On s1, enable Tailscale SSH: `sudo tailscale up --ssh` (or set `--ssh` on the existing
   `tailscale up` invocation).
4. In the ACL policy, define `tag:ci`, allow it to reach s1, and grant it SSH access to
   the `m1sk9` user via `ssh` rules. The policy is managed as IaC in
   [`tailscale/policy.hujson`](../tailscale/policy.hujson) — see the root
   [README](../README.md#tailscale) for how changes are tested and applied.
