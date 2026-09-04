terraform {
  backend "s3" {
    bucket       = "opentofu-state"
    key          = "homelab-compute.tfstate"
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
#module "proxmox" {
#  source = "../modules/proxmox"
#}
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