# Migrating the Beelink (Proxmox) to `hestia` (NixOS)

The NAS stays on Proxmox and keeps being managed by Ansible. This guide only covers the
Beelink guests.

| Proxmox guest | On hestia | URL |
|---|---|---|
| VM 100 homeassistant | Incus VM `haos` | https://homeassistant.welara-turtle.ts.net (HAOS Tailscale add-on) |
| CT 102 pi-hole | `nix/services/pihole.nix` | https://pi-hole.welara-turtle.ts.net/admin, DNS on 192.168.1.11 |
| CT 103 gitea | `nix/services/gitea.nix` | https://gitea.welara-turtle.ts.net, ssh://git@hestia.welara-turtle.ts.net:222 |
| CT 101 glance | `nix/services/glance.nix` | https://glance.welara-turtle.ts.net |
| CT 106 bentopdf | `nix/services/bentopdf.nix` | https://bentopdf.welara-turtle.ts.net |
| CT 104 pulse, 105 dannydots, 107 nextcloud | dropped | n/a |
| Proxmox UI | Incus UI | https://hestia.welara-turtle.ts.net:8443 |

## 1. Before anything: back up

Nothing on the Beelink is backed up today.

- HA: daily backups already go to the NAS. Make sure you have the backup **encryption key**
  (the emergency kit under Settings > System > Backups > *Backup settings*), because the
  restore asks for it. Take one extra manual backup right before shutting down VM 100.
- On the Beelink: `vzdump 101 102 103 106 --dumpdir /mnt/<nas-share> --mode snapshot`.

## 2. Hardware prep (HP ProDesk 600 G6 DM)

- **Drives** (see `nix/hosts/hestia/disko.nix`):
  - The included 256 GB NVMe stays in its M.2 slot. It's the system and boot disk, and holds
    the HAOS VM.
  - The 1 TB 2.5" SATA HDD goes in the drive bay as the backup disk. The bay needs HP's
    *Desktop Mini 2.5-inch SATA Drive Bay kit v2* (13L70AA), or at least the genuine HP
    SATA cable, if the unit came without one.
  - The second M.2 slot stays free for a future NVMe.
- **RAM:** the 32 GB module in one slot. A second 32 GB later gives 64 GB in dual channel.
- **Plug the ZBT-2 in via a USB extension cable** to keep it away from USB 3 interference.
- **Optional:** update the BIOS first (HP support site, or *Update System BIOS* in the menu).
- **BIOS settings (F10):**
  - *Advanced > System Options*: **Virtualization Technology (VTx)** and **VT for Directed
    I/O (VTd)** enabled.
  - *Advanced > Power-On Options*: **After Power Loss → Power On**.
  - *Advanced > Secure Boot Configuration*: **Secure Boot off** (systemd-boot is unsigned).
    The G6 boots UEFI-only, so there's no Legacy Support option to change.
  - *Advanced > Boot Options*: USB boot enabled, so you can boot the installer.

## 3. Prepare the config

1. Fill in the placeholders. `grep -rn CHANGE-ME nix/` lists them: both disk ids (from
   `ls -l /dev/disk/by-id/` on the installer), the NAS IP, and the new IP in `network.nix`
   (if `192.168.1.11` is taken).
2. In the Tailscale admin console, create two **reusable, pre-approved** auth keys: one for the
   host and one for tsnsrv. Tag them (for example `tag:server`) so the nodes don't expire.
3. Run `just edit-secrets` and fill in both keys, the Pi-hole password (reusing the old one
   keeps Glance happy) and a new restic password.

## 4. Install

Boot the new machine from a NixOS installer, set a root password (`passwd`) and note its IP.
Then run:

```sh
just install <installer-ip>      # nixos-anywhere: partitions (disko), writes hardware config, installs
```

The installer generates a new SSH host key, so the first boot can't decrypt secrets yet:

```sh
ssh-keyscan -t ed25519 192.168.1.11 | ssh-to-age    # add as &hestia in .sops.yaml
just rekey
just deploy
```

Commit the generated `hardware-configuration.nix` and `flake.lock`.

## 5. Cut over one service at a time

For each service, remove the old LXC's machine from the Tailscale admin console **before**
its tsnsrv node starts on hestia. Otherwise Tailscale renames the new node to `<name>-1`.
If that happens anyway, delete both, then `systemctl restart tsnsrv-<name>` on hestia.

### Pi-hole

1. Copy the adlists and Local DNS records from the old UI into `pihole.nix`, then deploy.
2. `dig @192.168.1.11 example.com` should answer, and a blocked domain should return `0.0.0.0`.
3. Point the router's DHCP DNS (and the tailnet DNS setting, if used) at `192.168.1.11`.
4. Stop CT 102, remove `pi-hole` from the tailnet, then `systemctl restart tsnsrv-pi-hole`.

### Gitea

The old Gitea only hosted a few mirrors, so it isn't migrated. Hestia runs a fresh Gitea on
SQLite (`nix/services/gitea.nix`) and the mirrors are recreated, so Gitea fetches them from
their sources again.

1. Note each mirror's source URL (old UI: the repo's *Settings > Repository*).
2. Stop CT 103, remove `gitea` (and `gitea-1`, if it exists) from the tailnet, then
   `systemctl restart tsnsrv-gitea`.
3. Registration is disabled, so create the admin on hestia:

   ```sh
   cd /var/lib/gitea
   sudo -u gitea gitea admin user create --admin --username <user> --email <email> \
     --random-password --must-change-password --config /var/lib/gitea/custom/conf/app.ini
   ```

4. Log in at https://gitea.welara-turtle.ts.net with the printed password, change it and set
   up 2FA.
5. Recreate each mirror with *+ > New Migration*, ticking *This repository will be a mirror*.
   A private source needs an access token.

SSH clones use the host's node and port 222:
`ssh://git@hestia.welara-turtle.ts.net:222/<owner>/<repo>.git`.

### Glance and BentoPDF

Neither has state. Stop CT 101 and CT 106, remove them from the tailnet, then restart
`tsnsrv-glance` and `tsnsrv-bentopdf`.

### Home Assistant OS

The cleanest path is a fresh HAOS restored from the backup made in step 1:

nixpkgs' Incus doesn't ship `incus-migrate`, so create an empty VM and write the image to
its disk:

```sh
# On hestia. Use the OVA image: generic-x86-64 is for bare metal, and in a VM the
# Supervisor flags it as "Incorrect OS image for virtualization" (unsupported).
# Take the latest release that has an OVA build
# (github.com/home-assistant/operating-system; some point releases are Raspberry Pi only)
v=<ver>
curl -LO https://github.com/home-assistant/operating-system/releases/download/$v/haos_ova-$v.qcow2.xz
nix shell nixpkgs#xz -c xz -d haos_ova-$v.qcow2.xz
nix shell nixpkgs#qemu-utils -c qemu-img convert -O raw haos_ova-$v.qcow2 haos_ova-$v.img

incus init haos --vm --empty \
  -c limits.cpu=4 -c limits.memory=8GiB -c boot.autostart=true -c security.secureboot=false
incus config device override haos root size=32GiB
# Keep the old MAC, so the router's DHCP reservation and IP stay the same
incus config set haos volatile.eth0.hwaddr=02:b8:44:43:bb:25
incus config device add haos zbt2 usb vendorid=303a productid=831a
dd if=haos_ova-$v.img bs=4M conv=notrunc,sparse \
  of=/var/lib/incus/storage-pools/default/virtual-machines/haos/root.img
```

Shut down VM 100 on Proxmox **before** starting the new VM, because both use the same MAC.
Then:

```sh
incus start haos
incus console haos --type=vga    # or open it from the Incus UI
```

Open HA at its old IP. During onboarding, choose **Restore from backup**. Check Zigbee/Thread
(ZHA or Z2M sees the ZBT-2) and the Tailscale add-on.

> Alternative: on Proxmox, `qemu-img convert -O raw /dev/flash/vm-100-disk-0 haos.img`, copy
> that to hestia and `dd` it instead of the fresh image. That keeps the VM bit-for-bit
> identical, but the backup restore is easier to reason about.

## 6. Incus UI

Open https://hestia.welara-turtle.ts.net:8443 and follow the prompts. The UI generates a
browser client certificate. Trust it on hestia with
`incus config trust add-certificate <file>` (or use the token flow the UI shows).

## 7. Wrap up

- Let it run in parallel for about a week, then `just restore-test`: restic restore into `/tmp`.
- Wipe the Beelink.
- Ansible: remove `proxmox`, `bentopdf`, `gitea`, `glance`, `pi-hole` and `pulse` from
  `hosts.yml`, `run.yml` and `roles/sync-files/tasks/main.yml`, along with their files
  and templates.
- Remove the old machines from the Tailscale admin console.
