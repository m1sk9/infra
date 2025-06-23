# infra

[![CI](https://github.com/m1sk9/infra/actions/workflows/ci.yaml/badge.svg)](https://github.com/m1sk9/infra/actions/workflows/ci.yaml)
[![CD](https://github.com/m1sk9/infra/actions/workflows/cd.yaml/badge.svg)](https://github.com/m1sk9/infra/actions/workflows/cd.yaml)
[![Test](https://github.com/m1sk9/infra/actions/workflows/test.yaml/badge.svg)](https://github.com/m1sk9/infra/actions/workflows/test.yaml)

Managed infrastructure for my open source projects.

![Diagram](./docs/diagram.svg)

## Background

This server configuration must meet the following requirements:

- Minimal time and effort required for maintenance.
- Use of Tailscale or Cloudflare Zero Trust to ensure that servers such as `dev-m1sk9-s1`are not exposed to the public internet.
- Independence from the home network.
- Applications running on the server should be containerized with Docker as much as possible.

## Architecture

### Common

- Applications run in Docker containers, and dynamic data is managed on the host file system.
- Users can only access the system if they are specifically invited, and only via Tailscale. Devices not connected to the Tailnet cannot access the servers.
- If Tailscale Funnel is unavailable, Cloudflare Zero Trust is used for authentication. In this case, only users with administrator-level, enhanced email addresses can connect; all others are denied access.

### dev-m1sk9-s1

- An Arch Linux server running on a laptop installed under the desk in the home office/library
- Docker Compose is managed via [m1sk9/infra](https://github.com/m1sk9/infra), and image updates are handled by Renovate

## Terraform

Terraform configuration files are located under the `/terraform` directory to manage various Cloudflare settings, such as for `m1sk9.dev`, as Infrastructure as Code (IaC).

These configurations are applied using GitHub Actions, which interact with the Cloudflare API.

- [`cloudflare_dns_record.tf`](./terraform/cloudflare_dns_record.tf): Manages DNS records
