#!/bin/sh
set -eu

# Destroying technitium_zone.primary/technitium_server_settings also needs
# both providers configured (same reason as bootstrap-apply.sh), so both
# tokens are required here too - read from the current state's own token
# files rather than the sops secrets file, since that value can go stale (a
# fresh container gets a fresh token; nothing updates secrets.enc.yaml
# automatically).
#
# Run via `make bootstrap-destroy`, which wraps this with `sops exec-env`.

TF_VAR_technitium_api_token="$(cat bootstrap/.technitium/dns1-token)" \
TF_VAR_technitium_api_token_dns2="$(cat bootstrap/.technitium/dns2-token)" \
  tofu -chdir=bootstrap destroy
