variable "proxmox_endpoint" {
  type    = string
  default = "https://proxmox2.local.courgettes.club"
}

variable "proxmox_api_token" {
  type      = string
  sensitive = true
}

variable "proxmox_insecure" {
  type    = bool
  default = false
}

variable "technitium_api_token" {
  type      = string
  sensitive = true
}