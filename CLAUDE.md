# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

The documentation for this repository is generally written in Japanese. Comments and CLAUDE.md are written in English.

## Overview

IaC for m1sk9's self-hosted infrastructure. Four independent layers live side by side:

| Directory | What it manages | How it is applied |
|---|---|---|
| `terraform/` | Cloudflare (DNS, Tunnel, Access, Workers, R2, rulesets, zone settings) and Better Stack (heartbeats, HTTP monitors, status page) | HCP Terraform (`m1sk9-terraform-org` / `infra`), CD on merge |
| `ansible/` | Host-level config on s1 / s2: restic backups, heartbeat timers, k3s bootstrap | CD on merge (`backup.yml`, `monitoring.yml` only) |
| `k8s/` | Workloads on the k3s cluster (s2 = server, s1 = agent) | ArgoCD syncs `k8s/apps/*` from `main` |
| `tailscale/policy.hujson` | Tailnet ACL | `gitops-acl-action` (test on PR, apply on merge) |

**Merging to `main` is a production deploy for every layer at once** — CD runs `terraform apply`, the Ansible playbooks, and the ACL apply, and ArgoCD picks up `k8s/` changes. There is no `paths` gating: every PR runs every CI job.

Hosts are reachable only inside the tailnet (MagicDNS `dev-m1sk9-s1`, `dev-m1sk9-s2`); nothing outside can poll them, so liveness is push-based (systemd timers → Better Stack heartbeats).

## Documentation

Each top-level directory (`ansible/`, `k8s/`, `tailscale/`, `terraform/`) has its own `README.md`, and the root `README.md` carries a short description of each. **Keep them in sync with every change**: when a change adds, removes, or alters what a directory manages, how it is applied, its required secrets, or its operational procedures, update that directory's `README.md` (and the root summary if the directory's role changes) in the same PR. These READMEs are written in Japanese.

`docs/DEPLOYMENT.md` is the deployment guide (how to deploy applications to k8s) and `docs/RESOURCE.md` covers how to use each infrastructure resource; update them too when a change affects those procedures.

Japanese documents follow these notation rules:

- Use `，` and `．` for punctuation.
- Use half-width parentheses, never full-width `（）`. Put a space before `(` when it follows text, and after `)` when text follows it, but not before punctuation such as `．`, `，` or `:` — e.g. `HCP Terraform (organization: ...) で管理します．`

## Tooling

All tool versions are pinned in `mise.toml` (`mise install`). Ansible is `pipx:ansible-core` via the uv backend. `lefthook` runs `terraform fmt -check` and `tflint` on commit for `*.tf`.

## Commands

Terraform (run in `terraform/`; plan needs an HCP Terraform token):

```sh
terraform fmt -check -recursive
tflint
terraform init && terraform validate
terraform plan -input=false
```

Ansible (run from `ansible/` — `ansible.cfg` uses relative paths; `ansible/.vault_pass` must exist even for `--syntax-check`):

```sh
ansible-playbook playbooks/<name>.yml --syntax-check
ansible-playbook playbooks/<name>.yml --check --diff   # the "plan", needs tailnet access
ansible-vault edit inventory/group_vars/all/vault.yml
```

Helm (what CI runs, per chart in `k8s/apps/`):

```sh
helm dependency update k8s/apps/<app>
helm lint k8s/apps/<app>
helm template <app> k8s/apps/<app> --namespace <app>
```

Sealed Secrets (the public cert is committed; secrets are namespace-scoped, so the namespace must equal the app directory name):

```sh
kubeseal --cert k8s/bootstrap/sealed-secrets-cert.pem --format yaml < secret.yaml
```

## Architecture notes

### k8s / ArgoCD

- `k8s/bootstrap/root.yaml` holds the `AppProject` and a git-directory `ApplicationSet`: **each `k8s/apps/<name>/` becomes one Application deployed to namespace `<name>`** with automated prune + selfHeal. Adding a service = adding a directory.
- Every app directory is a Helm chart. Upstream software uses an umbrella chart (`Chart.yaml` `dependencies` + `values.yaml`, with `Chart.lock` committed and `charts/` git-ignored); in-house bots put manifests in `templates/` and load `config.toml` into a ConfigMap via `.Files.Get`. Their `image:` is a literal `<repository>:<tag>` in `templates/deployment.yaml`, which Renovate's `kubernetes` manager scans line by line (`managerFilePatterns` in `.github/renovate.json`); a templated value would not be detected. `Chart.yaml` carries no `appVersion`, since nothing would keep it in sync.
- Placement uses the `m1sk9.dev/pool` node label (`apps` on s1, `observability` on s2), set via k3s config by the `k3s_node_labels` / `k3s_agent` roles. Discord bots are hard-pinned with `nodeSelector` and use `strategy: Recreate` (two instances with one token double-reply). Collectors are DaemonSets without a selector. ArgoCD is pinned to the control-plane node.
- Config mounted with `subPath` doesn't follow ConfigMap updates, so deployments carry a `checksum/config` annotation.
- Ingress is Cloudflare Tunnel (`k8s/apps/cloudflared`, tunnel + hostnames defined in `terraform/cloudflare_tunnel.tf`). traefik and servicelb are disabled. ArgoCD and Grafana sit behind Cloudflare Access; Prometheus/Loki are tailnet-only.
- Storage is k3s `local-path`, so PVCs are tied to their node.

### Ansible

- Inventory groups: `k3s_servers` (s2), `k3s_agents` (s1). Per-host data lives in `inventory/hosts.yml` and `inventory/host_vars/`.
- Roles are data-driven: `restic_backup` reads `backup_targets` (`sqlite_dbs`, `paths`, `pre_commands`), `heartbeat` reads `heartbeat_targets` (`name`, `url`, `oncalendar`, optional `check_command`). Add entries in vars, not role code. s1's lists are in `group_vars/all/vars.yml`, s2's override in `host_vars/s2.yml` (bot heartbeats run on s2 because that is where `k3s kubectl` works).
- Secrets: raw values in `group_vars/all/vault.yml` as `vault_*`, referenced from `vars.yml`. Heartbeat URLs are Terraform outputs copied into the vault by hand (Ansible can't read Terraform state).
- `k8s.yml` (s2 bootstrap, incl. one-shot ArgoCD install) and `k8s-agent.yml` (s1 join) are **not in CD**; they are run by hand. `argocd_bootstrap` is gated so re-runs are no-ops — ArgoCD manages itself afterwards via `k8s/apps/argocd`.
- s1 and s2 share one restic repository; s2's backup is offset by 30 min because `forget --prune` takes an exclusive lock.
- `helm_version` in `roles/argocd_bootstrap/defaults/main.yml` must match `helm` in `mise.toml`.

### Terraform

- Flat root module, one file per resource family. Cloudflare account/zone IDs are hard-coded in `main.tf` locals (not secrets).
- Some Better Stack settings (status page "Advanced settings") cannot be written via API on the free plan; they are deliberately left out of Terraform.

## Conventions

- Comments explain constraints and rejected alternatives ("why not"), in English; match that density.
- Required status checks on `main` are pinned to CI job names (`terraform-plan`, `ansible-plan`, …). Renaming a job requires updating the ruleset.
- Renovate manages versions, including a regex manager for `restic_version` in `roles/restic_backup/defaults/main.yml`.
