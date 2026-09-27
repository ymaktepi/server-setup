# Switch port assignments. Only the declared ports are managed; the others
# (port 1: uplink) keep whatever the controller has.
locals {
  network_ids = module.site.network_ids
}

resource "unifi_device" "salon_switch" {
  mac  = "f4:e2:c6:51:f7:db"
  name = "Salon-Switch-4-PoE"

  # On a fresh controller the provider adopts the (factory-reset) switch.
  # Never forget it just because it leaves tofu (the provider defaults to true).
  allow_adoption    = true
  forget_on_destroy = false

  port_override {
    index                 = 2
    name                  = "Hub Surefeed"
    native_networkconf_id = local.network_ids["crusted"]
    forward               = "native"
    tagged_vlan_mgmt      = "block_all"
  }

  port_override {
    index                 = 3
    name                  = "Port 3"
    native_networkconf_id = local.network_ids["default"]
    forward               = "native"
    tagged_vlan_mgmt      = "block_all"
  }

  port_override {
    index                 = 4
    name                  = "NAS Sarah"
    native_networkconf_id = local.network_ids["default"]
    forward               = "all"
    tagged_vlan_mgmt      = "auto"
  }

  port_override {
    index                 = 5
    name                  = "TV-Samsung"
    native_networkconf_id = local.network_ids["entertainment"]
    forward               = "native"
    tagged_vlan_mgmt      = "block_all"
  }
}

# LEDs off on the AP and the gateway. Only led_override is managed here; the
# rest of their config stays as set in the UI.
resource "unifi_device" "salon_ap" {
  mac               = "d8:b3:70:76:f6:12" # U6+
  forget_on_destroy = false
  led_override      = "off"
}

resource "unifi_device" "salon_gateway" {
  mac               = "94:2a:6f:cc:21:ff" # UDR7
  forget_on_destroy = false
  led_override      = "off"
}
