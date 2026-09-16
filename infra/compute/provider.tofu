provider "proxmox" {
  api_token = var.proxmox_api_token
  endpoint  = var.proxmox_endpoint
  insecure  = var.proxmox_insecure
  ssh {
    agent    = true
    username = "root"
  }
}

# dns1 is the Primary for var.technitium_zone (see bootstrap/main.tofu); dns2
# picks up records via zone transfer.
provider "technitium" {
  server_url      = "https://10.10.0.245"
  api_token       = var.technitium_api_token
  skip_tls_verify = true
}