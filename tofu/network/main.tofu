terraform {
  backend "s3" {
    bucket       = "opentofu-state"
    key          = "homelab-network.tfstate"
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
    unifi = {
      source  = "ubiquiti-community/unifi"
      version = "~> 0.56.1"
    }
  }
}
