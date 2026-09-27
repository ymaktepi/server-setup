# Any of the gateway's VLAN addresses reaches the same controller. Not
# 10.10.0.1: a remote site on the same 10.10.0.0/23 (reaching this one over
# Tailscale) has its own router at that address, and macOS pins the local
# gateway with a /32 route, so requests would hit the wrong router.
variable "unifi_api_url" {
  type        = string
  description = "Controller URL, without the /api path (e.g. https://<gateway-ip>)."
  default     = "https://10.10.2.1"
}

variable "unifi_api_key" {
  type      = string
  sensitive = true
}

variable "unifi_insecure" {
  type    = bool
  default = true
}

variable "unifi_site" {
  type    = string
  default = "default"
}

# Keyed like local.wlans (wlans.tofu). Set in secrets.enc.yaml as a JSON map.
variable "unifi_wlan_passphrases" {
  type      = map(string)
  sensitive = true
}
