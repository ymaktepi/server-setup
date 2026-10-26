terraform {
  backend "s3" {
    bucket       = "opentofu-state"
    key          = "homelab-netbird.tfstate"
    region       = "garage"
    use_lockfile = true

    endpoints = {
      s3 = "https://10.10.0.251:8443"
    }

    insecure                    = true
    skip_region_validation      = true
    skip_credentials_validation = true
    use_path_style              = true
  }
}

terraform {
  required_providers {
    netbird = {
      source  = "netbirdio/netbird"
      version = "~> 0.0.10"
    }
  }
}

# Self-hosted on the VPS (ansible: install_netbird_server). The token is a
# PAT of a service user created in the dashboard by the owner account.
provider "netbird" {
  management_url = var.netbird_management_url
  token          = var.netbird_token
}
