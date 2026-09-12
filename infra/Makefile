.PHONY: plan apply core-plan core-apply compute-plan compute-apply login install bootstrap-apply bootstrap-plan bootstrap-destroy format

login:
	@echo echo 'either copy paste the following or run eval "$$(make login)"'
	@echo export PROXMOX_VE_ENDPOINT=\"https://proxmox2.local.courgettes.club\"
	@echo export PROXMOX_VE_API_TOKEN=\'tofu@pve!provider=$$(op read 'op://infra/proxmox-opentofu-token/password')\'
	# set to true if you want to connect using the default self signed proxmox.domain:8006
	@echo export PROXMOX_VE_INSECURE=\"false\"
	@echo export AWS_ACCESS_KEY_ID=\"$$(op read 'op://infra/garage-opentofu-key/access_key_id')\"
	@echo export AWS_SECRET_ACCESS_KEY=\"$$(op read 'op://infra/garage-opentofu-key/password')\"

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

bootstrap-apply:
	tofu -chdir=bootstrap apply

bootstrap-destroy:
	tofu -chdir=bootstrap destroy

core-plan:
	tofu -chdir=core plan

core-apply:
	tofu -chdir=core apply

compute-plan:
	tofu -chdir=compute plan

compute-apply:
	tofu -chdir=compute apply