terraform {
  backend "s3" {
    bucket       = "opentofu-state"
    key          = "homelab-compute.tfstate"
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
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.113.1"
    }
    technitium = {
      source  = "darkhonor/technitium"
      version = "~> 1.2"
    }
  }
}
#module "proxmox" {
#  source = "../modules/proxmox"
#}
# Shared sources for container firewall rules (modules/lxc `firewall`);
# same values as core's.
locals {
  fw_admin = "10.10.0.0/23,10.20.0.20,10.20.0.21" # Bole Default + laptop at Salon
  fw_dmz   = "10.10.5.0/24"
}

module "containers" {
  source = "../modules/lxc"
  containers = {

    rsync_backup = {
      ctid       = 410
      node       = "proxmox"
      image_name = "debian-12-standard_12.2-1_amd64.tar.zst"

      cores  = 1
      cpus   = 1
      memory = 512

      vlan         = 1
      ipv4mode     = "static"
      ipv4_address = "10.10.0.249/23"
      ipv4_gateway = "10.10.0.1"

      ansible_groups = ["rsync_backup"]

      mounts = [
        {
          path      = "/mnt/mounted-raid/"
          volume    = "hdd-8tb-raid"
          size      = "200G"
          read_only = false
          backup    = false
        }
      ]
    }

    game_server = {
      ctid       = 414
      node       = "proxmox"
      image_name = "debian-12-standard_12.2-1_amd64.tar.zst"

      cores  = 6
      cpus   = 4
      memory = 16384
      disk   = 8

      vlan         = 5
      ipv4mode     = "static"
      ipv4_address = "10.10.5.248/24"
      ipv4_gateway = "10.10.5.1"

      # Game ports from anywhere; Factorio's RCON (27015/tcp) from Default
      # only, even though the port forward exposes it. Nothing into the DMZ.
      firewall = {
        rules = [
          { type = "in", proto = "udp", dport = "34197", comment = "factorio" },
          { type = "in", proto = "tcp", dport = "27015", source = "10.10.0.0/23", comment = "factorio RCON" },
          { type = "in", proto = "tcp", dport = "7777", comment = "satisfactory" },
          { type = "in", proto = "udp", dport = "7777", comment = "satisfactory" },
          { type = "in", macro = "SSH", source = local.fw_admin, comment = "admin SSH" },
          { type = "in", macro = "Ping", source = "10.10.0.0/23", comment = "ping from Default" },
          { type = "out", action = "DROP", dest = local.fw_dmz, comment = "rest of the DMZ" },
        ]
      }

      ansible_groups = ["game_server"]

      mounts = [
        {
          path      = "/mnt/mounted-raid/"
          volume    = "hdd-8tb-raid"
          size      = "200G"
          read_only = false
          backup    = false
        }
      ]
    }

    arr_server = {
      ctid       = 415
      node       = "proxmox"
      image_name = "debian-12-standard_12.2-1_amd64.tar.zst"

      cores        = 4
      cpus         = 4
      memory       = 4096
      disk         = 20
      datastore_id = "hdd-8tb-raid"

      vlan         = 5
      ipv4mode     = "static"
      ipv4_address = "10.10.5.247/24"
      ipv4_gateway = "10.10.5.1"

      ansible_groups = ["arr_server"]

      mounts = [
        {
          path      = "/mnt/mounted-raid/"
          volume    = "hdd-8tb-raid"
          size      = "1000G"
          read_only = false
          backup    = false
        }
      ]
      bind_mount = {
        source = "/mnt/lxc_shares/arr/"
        target = "/mnt/arr"
        backup = false
      }
      vpn = true
    }

    nextcloud = {
      ctid       = 417
      node       = "proxmox"
      image_name = "debian-12-standard_12.2-1_amd64.tar.zst"

      cores  = 4
      cpus   = 4
      memory = 4096
      disk   = 16

      vlan         = 5
      ipv4mode     = "static"
      ipv4_address = "10.10.5.246/24"
      ipv4_gateway = "10.10.5.1"

      ansible_groups = ["nextcloud"]

      mounts = [
        {
          path      = "/mnt/mounted-raid/"
          volume    = "hdd-8tb-raid"
          size      = "1000G"
          read_only = false
          backup    = false
        }
      ]
    }
  }
}