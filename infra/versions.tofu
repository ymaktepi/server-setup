terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.109"
    }
    random = {
      source  = "opentofu/random"
      version = "~> 3.6"
    }
  }
}