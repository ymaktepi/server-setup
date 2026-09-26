# Site-wide settings. Opt-in per group: only the groups declared here are
# managed; the rest stay as set in the UniFi UI. Destroying this resource only
# drops it from state (settings can't be deleted).
#
# Deliberately NOT managed (stay manual in the UI):
# - usg: the provider sends the whole group, so every unset toggle (ALG
#   modules, offloads, SYN cookies...) would be pushed as false. Its geo-IP
#   fields also don't reach this controller, which keeps country blocking
#   (RU,BR,CN ingress) in a separate usg_geo setting.
# - ips: same whole-group write, and the provider has no fields for ad
#   blocking or per-network DNS filters, which would risk wiping them.
resource "unifi_setting" "this" {
  mgmt = {
    auto_upgrade             = true
    auto_upgrade_hour        = 3
    advanced_feature_enabled = true
    direct_connect_enabled   = false
    debug_tools_enabled      = false
    unifi_idp_enabled        = true
    wifiman_enabled          = true
  }

  dpi = {
    enabled                = true
    fingerprinting_enabled = true
  }

  auto_speedtest = {
    enabled   = true
    cron_expr = "0 1 * * *"
  }

  # The custom querier switch isn't exposed by the provider; it's preserved
  # because this group is read-modify-written.
  igmp_snooping = {
    enabled = true
    network_ids = [
      unifi_network.this["entertainment"].id,
      unifi_network.this["guest"].id,
      unifi_network.this["crusted"].id,
    ]
  }
}
