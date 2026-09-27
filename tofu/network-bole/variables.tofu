# Any of the gateway's VLAN addresses reaches the same controller. 10.10.2.1
# rather than 10.10.0.1 dates from when Salon still used 10.10.x too (its own
# router was then also 10.10.0.1); either works now.
variable "unifi_api_url" {
  type        = string
  description = "Controller URL, without the /api path (e.g. https://<gateway-ip>)."
  default     = "https://10.10.2.1"
}

# Per-site name (TF_VAR_unifi_bole_api_key in secrets.enc.yaml): sops exec-env
# hands every stack every secret, so each site's key needs its own variable.
variable "unifi_bole_api_key" {
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

# Keyed like the module's wlan_catalogue; shared by all sites. Set in
# secrets.enc.yaml as a JSON map.
variable "unifi_wlan_passphrases" {
  type      = map(string)
  sensitive = true
}
