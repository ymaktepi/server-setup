# Existing UniFi config is adopted with import blocks rather than recreated.
# Add one per resource, then iterate until `make network-plan` shows no
# changes. `tofu plan -generate-config-out=generated.tofu` can draft the
# resource blocks for you.
#import {
#  to = unifi_network.main
#  id = "<network id>"
#}
