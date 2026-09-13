provider "proxmox" {
  api_token = var.proxmox_api_token
  endpoint = var.proxmox_endpoint
  insecure = var.proxmox_insecure
  ssh {
    agent = true
    username = "root"
  }
}