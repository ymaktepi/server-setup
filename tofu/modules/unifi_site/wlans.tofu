# Shared SSIDs, one per network (DMZ has none). Only those whose network
# exists at the site are created. Passphrases come from var.wlan_passphrases.
locals {
  wlan_catalogue = {
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

  wlans = { for k, w in local.wlan_catalogue : k => w if contains(keys(var.networks), w.network) }
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
  passphrase = var.wlan_passphrases[each.key]
  network_id = unifi_network.this[each.value.network].id

  ap_group_ids  = [data.unifi_ap_group.all.id]
  user_group_id = data.unifi_client_qos_rate.default.id

  wlan_band  = length(each.value.bands) > 1 ? "both" : each.value.bands[0]
  wlan_bands = each.value.bands

  # Controllers without per-SSID band steering never echo this field back;
  # left unset, the provider re-plans it as unknown on every run (perpetual
  # update). Pinned to match the APs' device-level setting.
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
