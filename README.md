# Homelab

Anything and everything regarding my homelab setup.

## Technologies

- **Proxmox** - Open source server virtualization management
- **Tailscale** - Mesh VPN
- **Ansible** - Configuration management
- **Just** - Task runner

## Services

- [**Home Assistant**](https://www.home-assistant.io/) - Home automation
- [**Glance**](https://github.com/glanceapp/glance) - Customizable dashboard

## Prerequisites

- Ansible
- Just
- SSH access to hosts

## Usage

```bash
just run [HOST] <[ARGS]>    # Run playbook for host
just sync-files [HOST]      # Synchronize host configuration files
just compose [HOST]         # Start services in 'lxc' host group
```
