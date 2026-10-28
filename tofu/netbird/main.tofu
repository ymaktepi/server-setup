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

# bootstrap's outputs (Technitium's servers and zones). Same bucket and
# settings as the backend above, which can't be shared: a backend block takes
# no variables. Credentials come from the same AWS_* environment.
data "terraform_remote_state" "bootstrap" {
  backend = "s3"
  config = {
    bucket = "opentofu-state"
    key    = "homelab-bootstrap.tfstate"
    region = "garage"

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
