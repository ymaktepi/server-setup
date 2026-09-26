# One SSID per network (DMZ has none). Passphrases come from
# var.unifi_wlan_passphrases (secrets.enc.yaml), keyed like this map.
locals {
  wlans = {
    appa = {
      name       = "Appa"
      network    = "default"
      bands      = ["2g", "5g"]
      no2ghz_oui = false
    }
    momo = {
      name       = "Momo"
      network    = "entertainment"
      bands      = ["2g", "5g"]
      no2ghz_oui = true
    }
    zuko = {
      name       = "Zuko"
      network    = "guest"
      bands      = ["2g", "5g"]
      no2ghz_oui = true
    }
    admiral_zhao = {
      name       = "AdmiralZhao"
      network    = "crusted"
      bands      = ["2g"] # IoT devices, 2.4 GHz only
      no2ghz_oui = true
    }
  }
}

data "unifi_ap_group" "all" {
  name = "All APs"
}

data "unifi_client_qos_rate" "default" {
  name = "Default"
}

resource "unifi_wlan" "this" {
  for_each = local.wlans

  name       = each.value.name
  passphrase = var.unifi_wlan_passphrases[each.key]
  network_id = unifi_network.this[each.value.network].id

  ap_group_ids  = [data.unifi_ap_group.all.id]
  user_group_id = data.unifi_client_qos_rate.default.id

  wlan_band  = length(each.value.bands) > 1 ? "both" : each.value.bands[0]
  wlan_bands = each.value.bands

  # This controller doesn't expose per-SSID band steering, so it never echoes
  # the field back; left unset, the provider re-plans it as unknown on every
  # run (perpetual update). Pinned to match the AP's device-level setting.
  bandsteering_mode = "off"

  security     = "wpapsk"
  wpa_mode     = "wpa2"
  wpa_enc      = "ccmp"
  pmf_mode     = "disabled"
  wpa3_support = false

  no2ghz_oui        = each.value.no2ghz_oui # 5 GHz-capable clients kept off 2.4 GHz
  group_rekey       = 0
  bss_transition    = true
  multicast_enhance = true
}
