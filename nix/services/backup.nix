# Nothing was backed up on Proxmox. Nightly MySQL dump, then restic twice:
#   local -> /var/backup/restic on the second NVMe (fast restores)
#   nas   -> the NAS over SFTP (off-box copy)
# HAOS backs itself up (Settings > System > Backups, to a NAS Samba share).
{ config, ... }:
let
  nas = "192.168.1.150"; # NAS LAN IP; hestia doesn't use MagicDNS

  common = {
    initialize = true;
    passwordFile = config.sops.secrets.restic_password.path;
    paths = [
      "/var/lib/gitea"
      "/var/lib/pihole"
    ];
    exclude = [ "/var/lib/gitea/data/tmp" ];
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
    ];
  };
in
{
  sops.secrets.restic_password = { };

  # Lands on the backup disk (/var/backup is its mountpoint)
  services.mysqlBackup = {
    enable = true;
    databases = [ "gitea" ];
    calendar = "02:00";
  };

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
    # The dumps live on the backup disk, so only the off-box copy needs them
    paths = common.paths ++ [ "/var/backup/mysql" ];
    timerConfig = {
      OnCalendar = "03:00";
      Persistent = true;
    };
  };
}
