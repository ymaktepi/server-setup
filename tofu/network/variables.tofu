variable "unifi_api_url" {
  type        = string
  description = "Controller URL, without the /api path (e.g. https://<gateway-ip>)."
  default = "https://10.10.0.1"
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
