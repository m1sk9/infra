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

## Terraform

Terraform configuration files are located under the [`/terraform`](./terraform) directory to manage Cloudflare DNS records for `m1sk9.dev` as Infrastructure as Code (IaC). State is managed by [HCP Terraform](https://app.terraform.io/) (organization: `m1sk9-terraform-org`, workspace: `infra`).

These configurations are applied automatically via GitHub Actions:

- **CI** (on pull request): Runs `terraform fmt`, `tflint`, `terraform validate`, and `terraform plan`.
- **CD** (on push to main): Runs `terraform plan` and `terraform apply`.

### Configuration Files

- [`cloudflare_dns_record.tf`](./terraform/cloudflare_dns_record.tf): Manages DNS records
- [`cloudflare_tunnel.tf`](./terraform/cloudflare_tunnel.tf): Manages Cloudflare Tunnels for secure server access
- [`main.tf`](./terraform/main.tf): Main Terraform configuration file
- [`outputs.tf`](./terraform/outputs.tf): Defines Terraform outputs (tunnel IDs, CNAMEs, etc.)
- [`provider.tf`](./terraform/provider.tf): Configures the Cloudflare provider
- [`variables.tf`](./terraform/variables.tf): Defines variables used in the Terraform configuration

### Cloudflare Tunnel

Cloudflare Tunnel is used to securely expose services running on self-hosted servers without opening firewall ports. Each server has its own tunnel resource (e.g., `s1` for server #1).

**Current tunnels:**
- `s1`: Server #1 tunnel, exposing services like `status.m1sk9.dev`

**Adding a new service to an existing tunnel:**

Add an ingress rule to the tunnel configuration in [`cloudflare_tunnel.tf`](./terraform/cloudflare_tunnel.tf):

```hcl
# Cloudflare Tunnel for server s1
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "s1" {
  account_id = local.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.s1.id
  config = {
    ingress = [
      {
        hostname = "status.m1sk9.dev"
        service  = "http://localhost:3001"
      },
      {
        hostname = "newservice.m1sk9.dev"  # Add your new service here
        service  = "http://localhost:PORT"
      },
      {
        service = "http_status:404"
      }
    ]
  }
}

# DNS Record for the new service
resource "cloudflare_dns_record" "newservice" {
  zone_id = local.cloudflare_zone_id
  name    = "newservice"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.s1.id}.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1
  proxied = true
  comment = "Cloudflare Tunnel - Service Description"
}
```

After updating the configuration, apply it with `terraform apply`. For server-side setup and cloudflared configuration, please contact [@m1sk9](https://github.com/m1sk9).

**Note:** Use single-level subdomains (e.g., `service.m1sk9.dev`) instead of multi-level subdomains (e.g., `service.s1.m1sk9.dev`) to ensure compatibility with Universal SSL certificates (`*.m1sk9.dev`).

## Dockge

[Dockge](https://github.com/louislam/dockge) is used to manage Docker containers on the self-hosted server. The Dockge configuration is located under the [`/dockge`](./dockge) directory.

- Runs on port `5001`
- Manages Docker Compose stacks in `/opt/stacks`
