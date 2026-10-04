# Cluster-wide switch for the Proxmox firewall. Per-container rules
# (modules/lxc's `firewall`) only take effect while this is enabled.
#
# The input/output policies here are the *nodes'* own (they don't apply to
# guests, which have their own via modules/lxc). Kept at ACCEPT so enabling
# the firewall changes nothing for the Proxmox hosts themselves - a DROP here
# would leave only 8006/22 from the cluster's local network, cutting off
# e.g. Salon (10.20.x) and anything else.
#
# Singleton: declare it once per cluster (here), never in compute/bootstrap.
resource "proxmox_virtual_environment_cluster_firewall" "this" {
  enabled        = true
  ebtables       = true
  input_policy   = "ACCEPT"
  output_policy  = "ACCEPT"
  forward_policy = "ACCEPT"
}
