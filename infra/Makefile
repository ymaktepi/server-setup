.PHONY: plan apply core-plan core-apply compute-plan compute-apply login install

login:
	@echo echo 'either copy paste the following or run eval "$$(make login)"'
	@echo export PROXMOX_VE_ENDPOINT=\"https://proxmox2.local.courgettes.club\"
	@echo export PROXMOX_VE_API_TOKEN=\"tofu@pve!provider=$$(op read 'op://infra/proxmox-opentofu-token/password')\"
	# set to true if you want to connect using the default self signed proxmox.domain:8006
	@echo export PROXMOX_VE_INSECURE=\"false\"
	@echo export AWS_ACCESS_KEY_ID=\"$$(op read 'op://infra/garage-opentofu-key/access_key_id')\"
	@echo export AWS_SECRET_ACCESS_KEY=\"$$(op read 'op://infra/garage-opentofu-key/password')\"

install:
	tofu init
	tofu -chdir=core init
	tofu -chdir=compute init

plan:
	$(MAKE) core-plan
	$(MAKE) compute-plan

apply:
	$(MAKE) core-apply
	$(MAKE) compute-apply

core-plan:
	tofu -chdir=core plan

core-apply:
	tofu -chdir=core apply

compute-plan:
	tofu -chdir=compute plan

compute-apply:
	tofu -chdir=compute apply