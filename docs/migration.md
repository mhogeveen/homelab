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

- HA: Settings > System > Backups > *Create backup* (full), then download it.
- On the Beelink: `vzdump 101 102 103 106 --dumpdir /mnt/<nas-share> --mode snapshot`.

## 2. Hardware prep (HP ProDesk 600 G6 DM)

- **Drives:** WD Black 1 TB in M.2 slot 1 (system and boot), the included 256 GB in slot 2
  (backups). See `nix/hosts/hestia/disko.nix`.
- **RAM:** the 32 GB module in one slot. A second 32 GB later gives 64 GB in dual channel.
- **Plug the ZBT-2 in via a USB extension cable** to keep it away from USB 3 interference.
- **Optional:** update the BIOS first (HP support site, or *Update System BIOS* in the menu).
- **BIOS settings (F10):**
  - *Advanced > System Options*: **Virtualization Technology (VTx)** and **VT for Directed
    I/O (VTd)** enabled.
  - *Advanced > Power-On Options*: **After Power Loss → Power On**.
  - *Advanced > Secure Boot Configuration*: **Legacy Support off, Secure Boot off**
    (systemd-boot is unsigned).
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

`nix/services/gitea.nix` runs Gitea 1.27.x from nixpkgs. Gitea can't downgrade, so check
the old version first:

```sh
ssh root@gitea 'docker exec gitea gitea --version'
```

If the old version is newer, wait for nixpkgs to catch up or override `services.gitea.package`.

```sh
# On the old LXC: stop Gitea, dump the DB and copy out the data volume
ssh root@gitea 'cd /docker/gitea && docker compose stop gitea \
  && docker compose exec db sh -c "mysqldump -u root -p\"\$MYSQL_ROOT_PASSWORD\" --single-transaction gitea" > /root/gitea.sql \
  && docker run --rm -v gitea_gitea:/data -v /root:/out alpine tar czf /out/gitea-data.tgz -C /data .'
scp root@gitea:/root/{gitea.sql,gitea-data.tgz} .
```

Then, on hestia:

```sh
systemctl stop gitea
mysql gitea < gitea.sql
mkdir /tmp/g && tar xzf gitea-data.tgz -C /tmp/g
# container layout          -> NixOS layout
# /data/git/repositories    -> /var/lib/gitea/repositories
# /data/git/lfs             -> /var/lib/gitea/data/lfs
# /data/gitea/{avatars,attachments,packages,...} -> /var/lib/gitea/data/
rsync -a /tmp/g/git/repositories/ /var/lib/gitea/repositories/
rsync -a /tmp/g/gitea/ /var/lib/gitea/data/ --exclude conf --exclude log --exclude sessions
```

Carry the secrets over from the old `/data/gitea/conf/app.ini`, one value per file. Without
`SECRET_KEY`, 2FA and other encrypted data can't be read.

```sh
cd /var/lib/gitea/custom/conf
for k in SECRET_KEY:secret_key INTERNAL_TOKEN:internal_token; do
  grep "^${k%%:*}" /tmp/g/gitea/conf/app.ini | cut -d= -f2- | tr -d ' ' > ${k##*:}
done
# [oauth2] JWT_SECRET -> oauth2_jwt_secret, [server] LFS_JWT_SECRET -> lfs_jwt_secret (if present)
chown -R gitea:gitea /var/lib/gitea
systemctl start gitea
sudo -u gitea gitea admin regenerate hooks --config /var/lib/gitea/custom/conf/app.ini
```

Remove `gitea` from the tailnet, restart `tsnsrv-gitea`, then log in and check repos and 2FA.
Update the SSH remotes, because the host changed and the port is still 222:

```sh
git remote set-url origin ssh://git@hestia.welara-turtle.ts.net:222/<owner>/<repo>.git
```

### Glance and BentoPDF

Neither has state. Stop CT 101 and CT 106, remove them from the tailnet, then restart
`tsnsrv-glance` and `tsnsrv-bentopdf`.

### Home Assistant OS

The cleanest path is a fresh HAOS restored from the backup made in step 1:

```sh
# On hestia. Use the latest generic-x86-64 release from github.com/home-assistant/operating-system
curl -LO https://github.com/home-assistant/operating-system/releases/download/<ver>/haos_generic-x86-64-<ver>.img.xz
xz -d haos_generic-x86-64-<ver>.img.xz

# Interactive: choose "virtual machine", name it "haos", give it the .img path,
# UEFI yes, Secure Boot no
incus-migrate

incus config set haos limits.cpu=4 limits.memory=8GiB boot.autostart=true
incus config device override haos root size=32GiB
# Keep the old MAC, so the router's DHCP reservation and IP stay the same
incus config set haos volatile.eth0.hwaddr=02:b8:44:43:bb:25
```

Shut down VM 100 on Proxmox **before** starting the new VM, because both use the same MAC.
Then:

```sh
incus config device add haos zbt2 usb vendorid=303a productid=831a
incus start haos
incus console haos --type=vga    # or open it from the Incus UI
```

Open HA at its old IP. During onboarding, choose **Restore from backup**. Check Zigbee/Thread
(ZHA or Z2M sees the ZBT-2) and the Tailscale add-on.

> Alternative: on Proxmox, `qemu-img convert -O qcow2 /dev/flash/vm-100-disk-0 haos.qcow2`,
> copy that to hestia and give it to `incus-migrate` instead of the fresh image. That keeps the VM bit-for-bit
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
