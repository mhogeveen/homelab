run HOST *ARGS:
  @ansible-playbook run.yml --limit {{HOST}} {{ARGS}}

sync-files HOST:
  @ansible-playbook run.yml --limit {{HOST}} --tags sync-files

compose HOST:
  @ansible-playbook run.yml --limit {{HOST}} --tags compose
