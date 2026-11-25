# Nothing was backed up on Proxmox. Nightly restic, twice:
#   local -> /var/backup/restic on the backup HDD (fast restores)
#   nas   -> the NAS over SFTP (off-box copy)
# HAOS backs itself up (Settings > System > Backups, to a NAS Samba share).
{ config, pkgs, ... }:
let
  nas = "192.168.1.150"; # NAS LAN IP; hestia doesn't use MagicDNS

  common = {
    initialize = true;
    passwordFile = config.sops.secrets.restic_password.path;
    paths = [
      "/var/lib/gitea"
      "/var/lib/pihole"
    ];
    exclude = [
      "/var/lib/gitea/data/tmp"
      "/var/lib/gitea/data/gitea.db*" # live file; the consistent copy below is backed up
    ];
    # Copying a live SQLite file can catch it mid-write; .backup takes a consistent snapshot
    backupPrepareCommand = ''
      ${pkgs.sqlite}/bin/sqlite3 /var/lib/gitea/data/gitea.db \
        ".backup '/var/lib/gitea/data/gitea-backup.sqlite'"
      chmod 600 /var/lib/gitea/data/gitea-backup.sqlite # holds password hashes
    '';
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
    ];
  };
in
{
  sops.secrets.restic_password = { };

  services.restic.backups.local = common // {
    repository = "/var/backup/restic";
    timerConfig = {
      OnCalendar = "02:30";
      Persistent = true;
    };
  };

  services.restic.backups.nas = common // {
    repository = "sftp:root@${nas}:/tank/backups/hestia";
    # Authorize /etc/ssh/ssh_host_ed25519_key.pub on the NAS for root
    extraOptions = [
      "sftp.command='ssh root@${nas} -i /etc/ssh/ssh_host_ed25519_key -o StrictHostKeyChecking=accept-new -s sftp'"
    ];
    timerConfig = {
      OnCalendar = "03:00";
      Persistent = true;
    };
  };
}
