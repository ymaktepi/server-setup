#!/bin/sh
set -eu

# Technitium's provider unconditionally pings its target server during
# configuration (no way to disable it), so it can't be configured until
# dns1 actually exists and responds - see the comment above the
# "technitium" provider in bootstrap/main.tofu for the full explanation.
# These 3 stages handle that regardless of whether this is a from-scratch
# bootstrap or a routine re-apply: on a routine apply each stage is just a
# "no changes" no-op once the previous one has already converged.
#
# Run via `make bootstrap-apply`, which wraps this with `sops exec-env` to
# provide TF_VAR_proxmox_api_token, TF_VAR_technitium_admin_password, etc.
# The dns1/dns2 API tokens below are separate - read fresh from local state
# on every run, not from the sops secrets file (see bootstrap/main.tofu's
# terraform_data.technitium_api_token).

tofu -chdir=bootstrap apply -auto-approve \
  -exclude=technitium_zone.primary \
  -exclude=technitium_zone.wildcard \
  -exclude=technitium_record.wildcard \
  -exclude=technitium_server_settings.dns1_forwarders \
  -exclude=technitium_server_settings.dns2_forwarders \
  -exclude=technitium_record.extra \
  -exclude=module.containers.technitium_record.containers

TF_VAR_technitium_api_token="$(cat bootstrap/.technitium/dns1-token)" \
TF_VAR_technitium_api_token_dns2="$(cat bootstrap/.technitium/dns2-token)" \
  tofu -chdir=bootstrap apply -auto-approve \
  -exclude=module.containers.technitium_record.containers

TF_VAR_technitium_api_token="$(cat bootstrap/.technitium/dns1-token)" \
TF_VAR_technitium_api_token_dns2="$(cat bootstrap/.technitium/dns2-token)" \
  tofu -chdir=bootstrap apply -auto-approve
