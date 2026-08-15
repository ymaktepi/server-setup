containers = {
  network_testing_default_vlan = {
    ctid       = 401
    node       = "proxmox4"
    image_name = "debian-12-standard_12.2-1_amd64.tar.zst"

    cores  = 1
    cpus   = 1
    memory = 512
    disk   = 4

    vlan         = 1
    ipv4mode     = "static"
    ipv4_address = "10.10.0.254/23"
    ipv4_gateway = "10.10.0.1"

  }

  network_testing_entertainment = {
    ctid       = 402
    node       = "proxmox4"
    image_name = "debian-12-standard_12.2-1_amd64.tar.zst"

    cores  = 1
    cpus   = 1
    memory = 512
    disk   = 4

    vlan         = 2
    ipv4mode     = "static"
    ipv4_address = "10.10.2.254/24"
    ipv4_gateway = "10.10.2.1"

  }

  network_testing_guest = {
    ctid       = 403
    node       = "proxmox4"
    image_name = "debian-12-standard_12.2-1_amd64.tar.zst"

    cores  = 1
    cpus   = 1
    memory = 512
    disk   = 4

    vlan         = 3
    ipv4mode     = "static"
    ipv4_address = "10.10.3.254/24"
    ipv4_gateway = "10.10.3.1"

  }

  network_testing_crusted = {
    ctid       = 404
    node       = "proxmox4"
    image_name = "debian-12-standard_12.2-1_amd64.tar.zst"

    cores  = 1
    cpus   = 1
    memory = 512
    disk   = 4

    vlan         = 4
    ipv4mode     = "static"
    ipv4_address = "10.10.4.254/24"
    ipv4_gateway = "10.10.4.1"

  }

  network_testing_dmz = {
    ctid       = 405
    node       = "proxmox4"
    image_name = "debian-12-standard_12.2-1_amd64.tar.zst"

    cores  = 1
    cpus   = 1
    memory = 512
    disk   = 4

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
    disk   = 4

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
    disk   = 4

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
    disk   = 4

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
    disk   = 4

    vlan         = 5
    ipv4mode     = "static"
    ipv4_address = "10.10.5.252/24"
    ipv4_gateway = "10.10.5.1"
  }

  rsync_backup = {
    ctid       = 410
    node       = "proxmox"
    image_name = "debian-12-standard_12.2-1_amd64.tar.zst"

    cores  = 1
    cpus   = 1
    memory = 512
    disk   = 4

    vlan         = 1
    ipv4mode     = "static"
    ipv4_address = "10.10.0.249/23"
    ipv4_gateway = "10.10.0.1"
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

  websites = {
    ctid       = 411
    node       = "proxmox2"
    image_name = "debian-12-standard_12.2-1_amd64.tar.zst"

    cores  = 1
    cpus   = 1
    memory = 512
    disk   = 4

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
    disk   = 4

    vlan         = 1
    ipv4mode     = "static"
    ipv4_address = "10.10.0.248/23"
    ipv4_gateway = "10.10.0.1"
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

  pocket = {
    ctid        = 500
    node        = "proxmox2"
    image_name  = "debian-12-standard_12.2-1_amd64.tar.zst"
    domain_name = ".pocket"

    cores  = 1
    cpus   = 1
    memory = 512
    disk   = 4

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
    disk   = 4

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