# nix develop on macOS sets a TMPDIR too long for SSH control sockets
export TMPDIR := "/tmp"

# --- NixOS (hestia) ---

build HOST="hestia":
  @nixos-rebuild build --flake .#{{HOST}}

deploy HOST="hestia" TARGET="root@192.168.1.11":
  @nixos-rebuild switch --flake .#{{HOST}} --target-host {{TARGET}} --build-host {{TARGET}}

# First install from a NixOS installer ISO; also writes hardware-configuration.nix
install IP HOST="hestia":
  @nix run nixpkgs#nixos-anywhere -- --flake .#{{HOST}} --build-on remote \
    --generate-hardware-config nixos-generate-config ./nix/hosts/{{HOST}}/hardware-configuration.nix \
    root@{{IP}}

edit-secrets HOST="hestia":
  @sops secrets/{{HOST}}.yaml

# Re-encrypt after changing recipients in .sops.yaml
rekey:
  @sops updatekeys secrets/*.yaml

# Restore the latest snapshot into /tmp/restore-test on hestia
restore-test TARGET="root@192.168.1.11":
  @ssh {{TARGET}} 'restic-nas restore latest --target /tmp/restore-test && du -sh /tmp/restore-test/*'

# --- Ansible (NAS + its LXCs) ---

run HOST *ARGS:
  @ansible-playbook run.yml --limit {{HOST}} --ask-vault-pass {{ARGS}}

sync-files HOST:
  @ansible-playbook run.yml --limit {{HOST}} --tags sync-files --ask-vault-pass

compose HOST:
  @ansible-playbook run.yml --limit {{HOST}} --tags compose --ask-vault-pass

update HOST:
  @ansible-playbook run.yml --limit {{HOST}} --tags update --ask-vault-pass

edit-vault:
  @ansible-vault edit roles/sync-files/vars/main/vault.yml
