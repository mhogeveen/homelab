# Homelab

Anything and everything regarding my homelab setup.

## Hosts

- **hestia** (NixOS, `nix/hosts/hestia`): HP ProDesk 600 G6 DM (i3-10100T, 32 GB, 256 GB NVMe system + 1 TB SATA HDD backups). Replaces the Beelink SEi13 Proxmox host. Runs Pi-hole, Gitea, Glance and BentoPDF natively, and Home Assistant OS as an Incus VM. See [docs/migration.md](docs/migration.md).
- **nas** (Proxmox, Ansible): UGREEN NASync DXP4800 Plus with Samba, Jellyfin, qBittorrent and Syncthing.

## Technologies

- **NixOS** + flakes: declarative config for hestia
- **Incus**: VMs (HAOS) and web UI
- **sops-nix**: secrets for hestia (`secrets/`, age keys in `.sops.yaml`)
- **tsnsrv**: one Tailscale node and HTTPS cert per service
- **Proxmox**: NAS
- **Tailscale**: mesh VPN
- **Ansible**: configuration management for the NAS
- **Just**: task runner

## Services

- [**Home Assistant**](https://www.home-assistant.io/): home automation
- [**Pi-hole**](https://pi-hole.net/) + unbound: DNS and ad-blocking
- [**Gitea**](https://about.gitea.com/): Git hosting
- [**Glance**](https://github.com/glanceapp/glance): customizable dashboard
- [**BentoPDF**](https://github.com/alam00000/bentopdf): PDF tools
- [**Jellyfin**](https://jellyfin.org/), [**qBittorrent**](https://www.qbittorrent.org/), [**Syncthing**](https://syncthing.net/): on the NAS

## Prerequisites

- Nix with flakes (`nix develop` provides just, ansible, sops and nixos-anywhere)
- SSH access to hosts

## Usage

```bash
# hestia (NixOS)
just build                  # Build the hestia config locally
just deploy                 # Build and switch hestia over SSH
just install <ip>           # First install via nixos-anywhere
just edit-secrets           # Edit secrets/hestia.yaml

# NAS (Ansible)
just run [HOST] <[ARGS]>    # Run playbook for host
just sync-files [HOST]      # Synchronize host configuration files
just compose [HOST]         # Start services in 'lxc' host group
```
