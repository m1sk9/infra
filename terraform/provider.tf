terraform {
  cloud {
    organization = "m1sk9-terraform-org"

    workspaces {
      name = "infra"
    }
  }

  required_version = ">= 1.12.1"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.23.0"
    }
    betteruptime = {
      source  = "BetterStackHQ/better-uptime"
      version = "0.21.12"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "betteruptime" {
  api_token = var.betteruptime_api_token
}
