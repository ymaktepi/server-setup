variable "proxmox_endpoint" {
  description = "Proxmox API endpoint, including the trailing slash"
  type        = string
  default     = null
}

variable "proxmox_api_token" {
  description = "Proxmox API token"
  type        = string
  sensitive   = true
  default     = null
}

variable "proxmox_insecure" {
  description = "Skip TLS certificate verification"
  type        = bool
  default     = false
}
