variable "proxmox_endpoint" {
  type = string
}

variable "proxmox_api_token" {
  type      = string
  sensitive = true
}

variable "proxmox_insecure" {
  type    = bool
  default = false
}

# Blank on the very first apply (see the comment above the "technitium"
# provider in main.tofu); set once the technitium_api_token output has been
# captured and stored in 1Password.
variable "technitium_api_token" {
  type      = string
  sensitive = true
  default   = ""
}

# Separate plain-bool flag (rather than checking technitium_api_token != ""
# directly) because a sensitive value can't drive a for_each condition.
# Defaults true since dns1/dns2 are already registered as of this commit.
# From-scratch bootstrap (after a full bootstrap-destroy) needs the 3-step
# -exclude dance documented above the "technitium" provider in main.tofu -
# this variable alone does NOT skip provider configuration.
variable "technitium_register_records" {
  type    = bool
  default = true
}