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
│   └── docker_compose_app/          # generic "deploy a compose stack" role
│       ├── tasks/main.yml
│       ├── defaults/main.yml
│       └── files/<service>/         # compose.yaml + vault-encrypted env/config
└── playbooks/
    ├── site.yml                     # connectivity check
    └── services.yml                 # deploy all Docker Compose services
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

Deploy or update all services (idempotent — unchanged stacks are not recreated):

```fish
ansible-playbook playbooks/services.yml
```

### Adding a service

1. Create `roles/docker_compose_app/files/<name>/compose.yaml` with a top-level `name:`.
2. Encrypt any secrets: `ansible-vault encrypt roles/docker_compose_app/files/<name>/env`
3. Add a block to `playbooks/services.yml` setting `app_name`, and as needed `app_files`
   (env/config to copy) and `app_dirs` (host directories to create).

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
```

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

## CI / CD

GitHub Actions deploys this configuration automatically, mirroring the Terraform setup.

- **CI** ([`ci.yaml`](../.github/workflows/ci.yaml)) — on pull requests
  touching `ansible/**`: runs `--syntax-check`, then a **plan**
  (`ansible-playbook playbooks/services.yml --check --diff`) against s1 so the PR shows
  exactly what would change — the Terraform `plan` equivalent. The `docker_compose_v2`
  module supports check mode, so the diff is meaningful. The Terraform plan job runs in
  the same workflow, gated by `paths-filter`.
- **CD** ([`cd.yaml`](../.github/workflows/cd.yaml)) — on push to `main`
  touching `ansible/**` (or manual `workflow_dispatch`): joins the tailnet, then runs
  `ansible-playbook playbooks/services.yml` against s1.

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
