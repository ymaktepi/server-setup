#!/bin/sh
set -eu

# Same token handling as bootstrap-apply.sh / bootstrap-destroy.sh: the
# dns1/dns2 API tokens are read fresh from local state, not from the sops
# secrets file (which has dns1's only), so the dns2-aliased technitium
# provider doesn't ping dns2 with its placeholder token and fail.
#
# Run via `make bootstrap-plan`, which wraps this with `sops exec-env`.

TF_VAR_technitium_api_token="$(cat bootstrap/.technitium/dns1-token)" \
TF_VAR_technitium_api_token_dns2="$(cat bootstrap/.technitium/dns2-token)" \
  tofu -chdir=bootstrap plan "$@"
