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

- OS: Arch Linux x86_64
- Shell: fish
- CPU: Intel Celeron 3855U
- GPU: Intel HD Graphics 510
- Memory: 4GB
- Swap: 2GB
- Disk: WDC WD10JPVX-08JC3T6

## Terraform

Terraform configuration files are located under the `/terraform` directory to manage various Cloudflare settings, such as for `m1sk9.dev`, as Infrastructure as Code (IaC).

These configurations are applied using GitHub Actions, which interact with the Cloudflare API.

- [`cloudflare_dns_record.tf`](./terraform/cloudflare_dns_record.tf): Manages DNS records
- [`main.tf`](./terraform/main.tf): Main Terraform configuration file
- [`provider.tf`](./terraform/provider.tf): Configures the Cloudflare provider
- [`variables.tf`](./terraform/variables.tf): Defines variables used in the Terraform configuration

## Configuration

### Docker Compose

Add configuration files under the `docker/` directory for Docker Compose. The minimum required files are as follows:

- .compose-cd: Configuration file for [compose-cd](https://github.com/sksat/compose-cd).

  ```
  REPO="https://github.com/m1sk9/infra"
  UPDATE_REPO_ONLY=true
  UPDATE_IMAGE_BY_REPO=true
  ```

- compose.yaml: Docker Compose configuration file.

  ```
  services:
    app:
      image: ghcr.io/m1sk9/babyrite:v0.17.6
      volumes:
        - ./config.toml:/config/config.toml
      restart: always
  ```

Tags must follow the `v*.*.*` format for compose-cd to work correctly.

Add application-specific configuration files as needed. When doing so, mount the host directory using the `volumes` option.
