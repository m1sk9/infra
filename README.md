# infra

[![CI](https://github.com/m1sk9/infra/actions/workflows/ci.yaml/badge.svg)](https://github.com/m1sk9/infra/actions/workflows/ci.yaml)
[![CD](https://github.com/m1sk9/infra/actions/workflows/cd.yaml/badge.svg)](https://github.com/m1sk9/infra/actions/workflows/cd.yaml)

Managed infrastructure for my open source projects.

![](./docs/infra-overview.png)

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
