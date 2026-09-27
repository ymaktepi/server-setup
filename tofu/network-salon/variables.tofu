variable "unifi_api_url" {
  type        = string
  description = "Controller URL, without the /api path (e.g. https://<gateway-ip>)."
  default     = "https://10.20.0.1"
}

# Per-site name (TF_VAR_unifi_salon_api_key in secrets.enc.yaml): sops
# exec-env hands every stack every secret, so each site's key needs its own
# variable.
variable "unifi_salon_api_key" {
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
