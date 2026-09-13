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

# Same as technitium_api_token but for the dns2-aliased provider.
variable "technitium_api_token_dns2" {
  type      = string
  sensitive = true
  default   = ""
}

# Port included explicitly (DoT's 853) to match what Technitium's API
# echoes back for Tls-protocol forwarders - the provider has a bug where it
# doesn't reconcile a plain-IP input against the port-suffixed value the
# server actually returns, causing an "inconsistent result after apply"
# error otherwise.
variable "technitium_forwarders" {
  type    = list(string)
  default = ["1.1.1.1:853", "1.0.0.1:853"] # Cloudflare
}

variable "technitium_forwarder_protocol" {
  type    = string
  default = "Tls"
}