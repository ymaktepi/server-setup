# DHCP reservations (var.clients).
#
# By default removing an entry only drops it from tofu and the controller keeps
# the device's history and reservation; see var.clients for how to really
# remove one (forget_on_destroy).
resource "unifi_client" "this" {
  for_each = var.clients

  mac              = each.value.mac
  name             = each.value.name
  fixed_ip         = each.value.fixed_ip
  local_dns_record = each.value.dns

  skip_forget_on_destroy = !each.value.forget_on_destroy
}
