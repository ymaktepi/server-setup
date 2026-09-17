.PHONY: plan apply core-plan core-apply compute-plan compute-apply install bootstrap-apply bootstrap-plan bootstrap-destroy format

SOPS_SECRETS := secrets.enc.yaml
SOPS_EXEC    := sops exec-env $(SOPS_SECRETS)

# sops exec-env's "command to run" must be passed as a single argument (see
# its usage line: `[file to decrypt] [command to run]`, singular) - splitting
# it across multiple argv entries (e.g. `$(SOPS_EXEC) tofu -chdir=core plan`)
# hits a real sops bug where it misparses and reports "missing file to
# decrypt" the moment the wrapped command has any argument at all. Every
# target below wraps its command in quotes for this reason - don't remove
# them. Scripts (bootstrap-apply.sh etc.) are unaffected since they're
# passed with no further args.

install:
	$(SOPS_EXEC) "tofu init -upgrade"
	$(SOPS_EXEC) "tofu -chdir=core init -upgrade"
	$(SOPS_EXEC) "tofu -chdir=compute init -upgrade"
	$(SOPS_EXEC) "tofu -chdir=bootstrap init -upgrade"

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
	$(SOPS_EXEC) "tofu -chdir=bootstrap plan"

bootstrap-apply:
	$(SOPS_EXEC) ./scripts/bootstrap-apply.sh

bootstrap-destroy:
	$(SOPS_EXEC) ./scripts/bootstrap-destroy.sh

core-plan:
	$(SOPS_EXEC) "tofu -chdir=core plan"

core-apply:
	$(SOPS_EXEC) "tofu -chdir=core apply"

compute-plan:
	$(SOPS_EXEC) "tofu -chdir=compute plan"

compute-apply:
	$(SOPS_EXEC) "tofu -chdir=compute apply"
