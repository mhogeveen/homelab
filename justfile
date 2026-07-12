run HOST *ARGS:
  @ansible-playbook run.yml --limit {{HOST}} --ask-vault-pass {{ARGS}}

sync-files HOST:
  @ansible-playbook run.yml --limit {{HOST}} --tags sync-files --ask-vault-pass

compose HOST:
  @ansible-playbook run.yml --limit {{HOST}} --tags compose

update HOST:
  @ansible-playbook run.yml --limit {{HOST}} --tags update

edit-vault:
  @ansible-vault edit roles/sync-files/vars/main/vault.yml
