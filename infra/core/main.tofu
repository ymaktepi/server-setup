terraform {
  backend "s3" {
    bucket       = "opentofu-state"
    key          = "homelab-core.tfstate"
    region       = "garage"
    use_lockfile = true

    endpoints = {
      s3 = "https://nas-2.nico"
    }

    insecure                    = true
    skip_region_validation      = true
    skip_credentials_validation = true
    use_path_style              = true
  }
}

terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.111"
    }
  }
}

module "containers" {
  source = "../modules/lxc"
  containers = {
    network_testing_default_vlan = {
      ctid       = 401
      node       = "proxmox4"
      image_name = "debian-12-standard_12.12-1_amd64.tar.zst"

      cores  = 1
      cpus   = 1
      memory = 512

      # fixme not tagged vlan
      # vlan = 1
      ipv4mode     = "static"
      ipv4_address = "10.10.0.254/23"
      ipv4_gateway = "10.10.0.1"
    }

    network_testing_entertainment = {
      ctid       = 402
      node       = "proxmox4"
      image_name = "debian-12-standard_12.12-1_amd64.tar.zst"

      cores  = 1
      cpus   = 1
      memory = 512

      vlan         = 2
      ipv4mode     = "static"
      ipv4_address = "10.10.2.254/24"
      ipv4_gateway = "10.10.2.1"

    }

    network_testing_guest = {
      ctid       = 403
      node       = "proxmox4"
      image_name = "debian-12-standard_12.12-1_amd64.tar.zst"

      cores  = 1
      cpus   = 1
      memory = 512

      vlan         = 3
      ipv4mode     = "static"
      ipv4_address = "10.10.3.254/24"
      ipv4_gateway = "10.10.3.1"

    }

    network_testing_crusted = {
      ctid       = 404
      node       = "proxmox4"
      image_name = "debian-12-standard_12.12-1_amd64.tar.zst"

      cores  = 1
      cpus   = 1
      memory = 512

      vlan         = 4
      ipv4mode     = "static"
      ipv4_address = "10.10.4.254/24"
      ipv4_gateway = "10.10.4.1"

    }

    network_testing_dmz = {
      ctid       = 405
      node       = "proxmox4"
      image_name = "debian-12-standard_12.12-1_amd64.tar.zst"

      cores  = 1
      cpus   = 1
      memory = 512

      vlan         = 5
      ipv4mode     = "static"
      ipv4_address = "10.10.5.254/24"
      ipv4_gateway = "10.10.5.1"
    }

    uptime_kuma = {
      ctid       = 406
      node       = "proxmox2"
      image_name = "debian-12-standard_12.2-1_amd64.tar.zst"

      cores  = 1
      cpus   = 1
      memory = 512

      vlan         = 1
      ipv4mode     = "static"
      ipv4_address = "10.10.0.253/23"
      ipv4_gateway = "10.10.0.1"
    }

    traefik_default = {
      ctid       = 407
      node       = "proxmox2"
      image_name = "debian-12-standard_12.2-1_amd64.tar.zst"

      cores  = 1
      cpus   = 1
      memory = 512

      vlan         = 1
      ipv4mode     = "static"
      ipv4_address = "10.10.0.250/23"
      ipv4_gateway = "10.10.0.1"
    }

    traefik_dmz = {
      ctid       = 408
      node       = "proxmox3"
      image_name = "debian-12-standard_12.2-1_amd64.tar.zst"

      cores  = 1
      cpus   = 1
      memory = 512

      vlan         = 5
      ipv4mode     = "static"
      ipv4_address = "10.10.5.250/24"
      ipv4_gateway = "10.10.5.1"
    }

    jumphost = {
      ctid       = 409
      node       = "proxmox2"
      image_name = "debian-12-standard_12.2-1_amd64.tar.zst"

      cores  = 1
      cpus   = 1
      memory = 512

      vlan         = 5
      ipv4mode     = "static"
      ipv4_address = "10.10.5.252/24"
      ipv4_gateway = "10.10.5.1"
    }

    websites = {
      ctid       = 411
      node       = "proxmox2"
      image_name = "debian-12-standard_12.2-1_amd64.tar.zst"

      cores  = 1
      cpus   = 1
      memory = 512

      vlan         = 5
      ipv4mode     = "static"
      ipv4_address = "10.10.5.249/24"
      ipv4_gateway = "10.10.5.1"
    }

    vpn = {
      ctid       = 412
      node       = "proxmox2"
      image_name = "debian-12-standard_12.2-1_amd64.tar.zst"

      cores  = 1
      cpus   = 1
      memory = 512

      vlan         = 1
      ipv4mode     = "static"
      ipv4_address = "10.10.0.248/23"
      ipv4_gateway = "10.10.0.1"
    }

    pocket = {
      ctid        = 500
      node        = "proxmox2"
      image_name  = "debian-12-standard_12.2-1_amd64.tar.zst"
      domain_name = ".pocket"

      cores  = 1
      cpus   = 1
      memory = 512

      vlan         = 5
      ipv4mode     = "static"
      ipv4_address = "10.10.5.100/24"
      ipv4_gateway = "10.10.5.1"
      mounts = [
        {
          path      = "/mnt/mounted-raid/"
          volume    = "synology"
          size      = "8G"
          read_only = false
          backup    = true
        }
      ]
    }

    bear = {
      ctid        = 503
      node        = "proxmox2"
      image_name  = "debian-12-standard_12.2-1_amd64.tar.zst"
      domain_name = ".bear"

      cores  = 2
      cpus   = 2
      memory = 1024

      vlan         = 5
      ipv4mode     = "static"
      ipv4_address = "10.10.5.103/24"
      ipv4_gateway = "10.10.5.1"
      mounts = [
        {
          path      = "/mnt/mounted-raid/"
          volume    = "synology"
          size      = "50G"
          read_only = false
          backup    = false
        }
      ]
    }
  }
}