# infra

[![CI](https://github.com/m1sk9/infra/actions/workflows/ci.yaml/badge.svg)](https://github.com/m1sk9/infra/actions/workflows/ci.yaml)
[![CD](https://github.com/m1sk9/infra/actions/workflows/cd.yaml/badge.svg)](https://github.com/m1sk9/infra/actions/workflows/cd.yaml)

Managed infrastructure for my open source projects.

## Background

This server configuration must meet the following requirements:

- Minimal time and effort required for maintenance.
- Use of Tailscale or Cloudflare Zero Trust to ensure that servers are not exposed to the public internet.
- Independence from the home network.
- Applications running on the server should be containerized with Docker as much as possible.

## Architecture

> A detailed infrastructure diagram is available at [`docs/infra-overview.drawio`](./docs/infra-overview.drawio).

- Applications run in Docker containers, and dynamic data is managed on the host file system.
- Users can only access the system if they are specifically invited, and only via Tailscale. Devices not connected to the Tailnet cannot access the servers.
- If Tailscale Funnel is unavailable, Cloudflare Zero Trust is used for authentication. In this case, only users with administrator-level, enhanced email addresses can connect; all others are denied access.

## Network

> For details on the network topology, see [`network/README.md`](./network/README.md).

The home network runs on a SoftBank 光 10G fiber connection. All devices are connected via Tailscale, and external access to internal resources is denied. Services that need to be publicly accessible are exposed through Cloudflare Zero Trust Tunnels without any port forwarding.

## Terraform

Terraform configuration files are located under the [`/terraform`](./terraform) directory to manage Cloudflare DNS records for `m1sk9.dev` as Infrastructure as Code (IaC). State is managed by [HCP Terraform](https://app.terraform.io/) (organization: `m1sk9-terraform-org`, workspace: `infra`).

These configurations are applied automatically via GitHub Actions:

- **CI** (on pull request): Runs `terraform fmt`, `tflint`, `terraform validate`, and `terraform plan`.
- **CD** (on push to main): Runs `terraform plan` and `terraform apply`.

### Configuration Files

- [`cloudflare_access.tf`](./terraform/cloudflare_access.tf): Manages Cloudflare Zero Trust Access (GitHub OAuth IdP, access policies, and applications)
- [`cloudflare_dns_record.tf`](./terraform/cloudflare_dns_record.tf): Manages DNS records
- [`cloudflare_tunnel.tf`](./terraform/cloudflare_tunnel.tf): Manages Cloudflare Tunnels for secure server access
- [`cloudflare_worker.tf`](./terraform/cloudflare_worker.tf): Manages Cloudflare Workers and custom domains
- [`main.tf`](./terraform/main.tf): Main Terraform configuration file
- [`outputs.tf`](./terraform/outputs.tf): Defines Terraform outputs (tunnel IDs, CNAMEs, etc.)
- [`provider.tf`](./terraform/provider.tf): Configures the Cloudflare provider
- [`variables.tf`](./terraform/variables.tf): Defines variables used in the Terraform configuration

### Cloudflare Tunnel

Cloudflare Tunnel is used to securely expose services running on self-hosted servers without opening firewall ports. Tunnel definitions are managed in [`cloudflare_tunnel.tf`](./terraform/cloudflare_tunnel.tf).

## Ansible

Server configuration management lives under the [`/ansible`](./ansible) directory. Hosts are reached over the Tailscale tailnet via their MagicDNS names, and secrets are protected with `ansible-vault`.

See [`ansible/README.md`](./ansible/README.md) for setup, secret handling, and usage.

## Tailscale

The tailnet policy file (ACL) is managed as IaC in [`tailscale/policy.hujson`](./tailscale/policy.hujson), synced via [`tailscale/gitops-acl-action`](https://tailscale.com/docs/integrations/github/gitops):

- **CI** (on pull request): Runs `action: test` — validates the policy without touching the tailnet.
- **CD** (on push to main): Runs `action: apply` — validates and, if successful, updates the live ACL.

The NextDNS profile ID embedded in the policy is not committed in plaintext; it is substituted from the `NEXTDNS_PROFILE_ID` secret via `envsubst` before the action reads the file.

### Required GitHub secrets

| Secret | Purpose |
|---|---|
| `TS_OAUTH_CLIENT_ID_ACL` | OAuth client id, scoped to `Policy File` (Read+Write) |
| `TS_OAUTH_SECRET_ACL` | OAuth client secret for the same client |
| `TS_TAILNET` | Tailnet identifier (find via `tailscale status --json` → `CurrentTailnet.Name`) |
| `NEXTDNS_PROFILE_ID` | NextDNS profile id referenced by `nodeAttrs` in the policy |

These are separate from the `TS_OAUTH_CLIENT_ID` / `TS_OAUTH_SECRET` used by `ansible`'s CI/CD (see [`ansible/README.md`](./ansible/README.md#tailscale-setup-one-time)) — that client only has the `auth_keys` scope and cannot read or write the policy file.

### One-time setup

1. In the Tailscale admin console, go to **Settings → OAuth clients** and generate a new
   client with the **Policy File** scope, enabling both **Read** and **Write** (apply
   needs write access).
2. Register the id/secret and the other two values as GitHub secrets. Prefer the
   interactive prompt for the OAuth secret so it never touches shell history:

   ```
   gh secret set TS_OAUTH_CLIENT_ID_ACL --repo m1sk9/infra
   gh secret set TS_OAUTH_SECRET_ACL --repo m1sk9/infra
   gh secret set TS_TAILNET --repo m1sk9/infra --body "m1sk9.github"
   gh secret set NEXTDNS_PROFILE_ID --repo m1sk9/infra --body "5a9f5d"
   ```
3. Open a PR touching `tailscale/policy.hujson` and confirm the `tailscale-acl-test` job
   passes before merging.
