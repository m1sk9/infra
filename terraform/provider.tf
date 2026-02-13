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
      version = "5.17.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
