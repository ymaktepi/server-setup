# Shared SSIDs, one per network (DMZ has none). Only those whose network
# exists at the site are created. Passphrases come from var.wlan_passphrases.
locals {
  wlan_catalogue = {
    appa = {
      name       = "Appa"
      network    = "default"
      bands      = ["2g", "5g"]
      no2ghz_oui = false
      wpa3       = true
    }
    momo = {
      name       = "Momo"
      network    = "entertainment"
      bands      = ["2g", "5g"]
      no2ghz_oui = true
      wpa3       = false
    }
    zuko = {
      name       = "Zuko"
      network    = "guest"
      bands      = ["2g", "5g"]
      no2ghz_oui = true
      wpa3       = true
    }
    admiral_zhao = {
      name       = "AdmiralZhao"
      network    = "crusted"
      bands      = ["2g"] # IoT devices, 2.4 GHz only
      no2ghz_oui = true
      wpa3       = false
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

  # WPA2/WPA3 transition with optional management-frame protection where
  # every client copes; WPA2-only (PMF off) on the SSIDs with older TVs,
  # soundbars and IoT gear (wpa3 = false in the catalogue).
  security        = "wpapsk"
  wpa_mode        = "wpa2"
  wpa_enc         = "ccmp"
  pmf_mode        = each.value.wpa3 ? "optional" : "disabled"
  wpa3_support    = each.value.wpa3
  wpa3_transition = each.value.wpa3

  no2ghz_oui        = each.value.no2ghz_oui # 5 GHz-capable clients kept off 2.4 GHz
  group_rekey       = 0
  bss_transition    = true
  multicast_enhance = true
}
