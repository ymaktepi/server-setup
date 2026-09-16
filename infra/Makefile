.PHONY: plan apply core-plan core-apply compute-plan compute-apply login install bootstrap-apply bootstrap-plan bootstrap-destroy format

login:
	@echo echo 'either copy paste the following or run eval "$$(make login)"'
	@echo export TF_VAR_proxmox_endpoint=\"https://proxmox2.local.courgettes.club\"
	@echo export TF_VAR_proxmox_api_token=\'root@pam!tofu=$$(op read 'op://infra/proxmox-opentofu-token/password')\'
	# set to true if you want to connect using the default self signed proxmox.domain:8006
	@echo export TF_VAR_proxmox_insecure=\"false\"
	@echo export AWS_ACCESS_KEY_ID=\"$$(op read 'op://infra/garage-opentofu-key/access_key_id')\"
	@echo export AWS_SECRET_ACCESS_KEY=\"$$(op read 'op://infra/garage-opentofu-key/password')\"
	@echo export TF_VAR_technitium_api_token=\'$$(op read 'op://infra/technitium-api-token/credential')\'

install:
	tofu init -upgrade
	tofu -chdir=core init -upgrade
	tofu -chdir=compute init -upgrade
	tofu -chdir=bootstrap init -upgrade

plan:
	$(MAKE) bootstrap-plan
	$(MAKE) core-plan
	$(MAKE) compute-plan

apply:
	$(MAKE) bootstrap-apply
	$(MAKE) core-apply
	$(MAKE) compute-apply

format:
	tofu -chdir=bootstrap fmt
	tofu -chdir=core fmt
	tofu -chdir=compute fmt

bootstrap-plan:
	tofu -chdir=bootstrap plan

# Technitium's provider unconditionally pings its target server during
# configuration (no way to disable it), so it can't be configured until
# dns1 actually exists and responds - see the comment above the "technitium"
# provider in bootstrap/main.tofu for the full explanation. These 3 stages
# handle that regardless of whether this is a from-scratch bootstrap or a
# routine re-apply: on a routine apply each stage is just a "no changes"
# no-op once the previous one has already converged.
bootstrap-apply:
	tofu -chdir=bootstrap apply -auto-approve \
		-exclude=technitium_zone.primary \
		-exclude=technitium_zone.wildcard \
		-exclude=technitium_record.wildcard \
		-exclude=technitium_server_settings.dns1_forwarders \
		-exclude=technitium_server_settings.dns2_forwarders \
		-exclude=technitium_record.extra \
		-exclude=module.containers.technitium_record.containers
	TF_VAR_technitium_api_token="$$(cat bootstrap/.technitium/dns1-token)" \
	TF_VAR_technitium_api_token_dns2="$$(cat bootstrap/.technitium/dns2-token)" \
		tofu -chdir=bootstrap apply -auto-approve \
		-exclude=module.containers.technitium_record.containers
	TF_VAR_technitium_api_token="$$(cat bootstrap/.technitium/dns1-token)" \
	TF_VAR_technitium_api_token_dns2="$$(cat bootstrap/.technitium/dns2-token)" \
		tofu -chdir=bootstrap apply -auto-approve

# Destroying technitium_zone.primary/technitium_server_settings also needs
# both providers configured (same reason as bootstrap-apply above), so both
# tokens are required here too - read from the current state's own token
# files rather than 1Password, since that value can go stale (a fresh
# container gets a fresh token; nothing updates 1Password automatically).
bootstrap-destroy:
	TF_VAR_technitium_api_token="$$(cat bootstrap/.technitium/dns1-token)" \
	TF_VAR_technitium_api_token_dns2="$$(cat bootstrap/.technitium/dns2-token)" \
		tofu -chdir=bootstrap destroy

core-plan:
	tofu -chdir=core plan

core-apply:
	tofu -chdir=core apply

compute-plan:
	tofu -chdir=compute plan

compute-apply:
	tofu -chdir=compute apply