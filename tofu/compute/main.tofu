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
# The GPU on node `proxmox`, as cluster resource mappings: an API token may
# only pass through mapped devices (see modules/vms `hostpci`). IDs from
# `pvesh get /nodes/proxmox/hardware/pci`.
resource "proxmox_hardware_mapping_pci" "gpu" {
  name    = "gpu"
  comment = "RTX 3060 (gpu VM)"
  map = [{
    node         = "proxmox"
    path         = "0000:01:00.0"
    id           = "10de:2504"
    subsystem_id = "1458:40e2"
    iommu_group  = 8
  }]
}

resource "proxmox_hardware_mapping_pci" "gpu_audio" {
  name    = "gpu-audio"
  comment = "RTX 3060 HDMI audio (gpu VM)"
  map = [{
    node         = "proxmox"
    path         = "0000:01:00.1"
    id           = "10de:228e"
    subsystem_id = "1458:40e2"
    iommu_group  = 8
  }]
}

module "vms" {
  source = "../modules/vms"

  images = {
    debian12 = {
      url      = "https://cloud.debian.org/images/cloud/bookworm/20260923-2610/debian-12-generic-amd64-20260923-2610.qcow2"
      checksum = "b789a983661b93ae280dcebbcecc425e7a05f15ab4a60d08e0bf130759a4f84dd26de39bd0e77e33b3f513910e5c5e84bdb335324b5138b4c43a0899a1733455"
    }
  }

  vms = {
    gpu = {
      vmid = 302
      node = "proxmox" # the node with the GPU

      cores        = 4
      memory       = 16384
      disk_size    = 100
      datastore_id = "m2-noraid"
      image        = "debian12"

      started = true
      on_boot = false

      machine = "q35"
      hostpci = [
        { mapping = proxmox_hardware_mapping_pci.gpu.name, rombar = false },
        { mapping = proxmox_hardware_mapping_pci.gpu_audio.name },
      ]

      vlan         = 5
      ipv4mode     = "static"
      ipv4_address = "10.10.5.102/24"
      ipv4_gateway = "10.10.5.1"

      ansible_groups = ["gpu"]
      ansible_vars   = [{ key = "ansible_user", value = "ansible" }]
    }
  }
}
