# Addressed by IP rather than hostname: this stack manages the network that
# everything else at the site sits on, so it mustn't depend on DNS.
provider "unifi" {
  api_url        = var.unifi_api_url
  api_key        = var.unifi_salon_api_key
  allow_insecure = var.unifi_insecure
  site           = var.unifi_site
}
