# tofu/

OpenTofu for the Proxmox homelab, split into three independent stacks
(`bootstrap`, `core`, `compute` — see the repo-root `CLAUDE.md` for the
architecture). This file covers secrets: they're managed with
[`sops`](https://github.com/getsops/sops) + [`age`](https://github.com/FiloSottile/age),
Every genuinely sensitive value lives in `tofu/secrets.enc.yaml`, encrypted at rest, checked into git, and
decrypted on the fly per-command by `make` via `sops exec-env` — decryption
needs only a local age private key, no external app or service.

The same age identity and repo-root `.sops.yaml` config also cover
`ansible/`'s secrets (`inventory/group_vars/all/vault.sops.yaml`) — one
key, one config, two encrypted files. Everything below applies to both; see
`../ansible/README.md` for the Ansible-specific half.

## Prerequisites

```bash
brew install sops age   # macOS; see https://github.com/getsops/sops and
                         # https://github.com/FiloSottile/age for other OSes
```

## Generate your own age key

```bash
age-keygen -o ~/.config/sops/age/keys.txt
```

This writes a keypair to that file (the private key, with a `# public key:
age1...` comment above it). Then make sure `sops` actually looks there —
its default lookup path differs between macOS and Linux, so don't rely on
it; add this to your shell profile instead:

```bash
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
```

Send your **public** key (the `age1...` string — never the private key file
itself) to whoever can currently decrypt `secrets.enc.yaml`, so they can add
you as a recipient (see below). Until they do, `sops`/`make` commands here
will fail to decrypt for you.

## Day-to-day usage

Nothing — once your key is a recipient, `make bootstrap-apply` and friends
just work. There's no login step to run first.

## Editing secrets

```bash
sops tofu/secrets.enc.yaml
```

Opens `$EDITOR` with the decrypted content; saving re-encrypts
automatically per `.sops.yaml`'s rule for that file. Top-level keys are
exactly the env var names the Makefile injects (e.g.
`TF_VAR_proxmox_api_token`, `AWS_ACCESS_KEY_ID`) — add a new key here and
it's available to every `make` target immediately, no other wiring needed.

## Adding a new key (new machine, or a collaborator)

1. They generate their own key as above (`age-keygen ...`) and send you
   their **public** key.
2. Add it to the repo-root `.sops.yaml`'s `key_groups` list (both
   `creation_rules` entries share the same `key_groups`, so one edit covers
   both files).
3. Re-wrap each existing file for the new recipient set (requires your own
   key to still be a valid recipient):
   ```bash
   sops updatekeys tofu/secrets.enc.yaml
   sops updatekeys ansible/inventory/group_vars/all/vault.sops.yaml
   ```
   This doesn't require re-typing any secret values — it just re-encrypts
   each file's data key for the updated recipient list.

## What's actually in `secrets.enc.yaml`

- `TF_VAR_proxmox_api_token` — Proxmox API token (`USER@REALM!TOKENID=UUID`).
- `TF_VAR_technitium_api_token` — Technitium API token for dns1, used by
  `core`/`compute` to register DNS records (see `bootstrap/main.tofu`'s
  `technitium` provider comments for why this can't be dns2's token, or a
  freshly-created one — this is the long-lived value that gets captured
  after a `bootstrap-apply` and stored here).
- `TF_VAR_technitium_admin_password` — Technitium's admin password, baked
  into the dns1/dns2 LXC image at build time. Changing this value forces an
  image rebuild on the next `bootstrap-apply` (see the trigger comment on
  `terraform_data.technitium_template`) — it doesn't take effect on a
  running dns1/dns2 without also recreating them
  (`bootstrap-destroy` + `bootstrap-apply`).
- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` — Garage (S3-compatible)
  credentials for the OpenTofu state backend itself.