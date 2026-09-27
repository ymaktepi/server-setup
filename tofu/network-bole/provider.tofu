# Addressed by IP rather than hostname: this stack manages the network that
# the DNS (and everything else) sits on, so it mustn't depend on it.
provider "unifi" {
  api_url        = var.unifi_api_url
  api_key        = var.unifi_bole_api_key
  allow_insecure = var.unifi_insecure
  site           = var.unifi_site
}
