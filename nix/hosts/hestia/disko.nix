# HP ProDesk 600 G6 DM: two NVMe drives. Find the ids with `ls -l /dev/disk/by-id/`
# on the installer.
{
  # WD Black 1 TB in M.2 slot 1: boot + system + Incus pool
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/disk/by-id/nvme-WD_BLACK_CHANGE-ME";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [ "-f" ];
            subvolumes = {
              "@root" = {
                mountpoint = "/";
                mountOptions = [
                  "compress=zstd"
                  "noatime"
                ];
              };
              "@nix" = {
                mountpoint = "/nix";
                mountOptions = [
                  "compress=zstd"
                  "noatime"
                ];
              };
              # Incus btrfs storage pool (see incus.nix); VM disks become subvolumes here
              "@incus" = {
                mountpoint = "/var/lib/incus-pool";
                mountOptions = [ "noatime" ];
              };
              "@swap" = {
                mountpoint = "/swap";
                swap.swapfile.size = "8G";
              };
            };
          };
        };
      };
    };
  };

  # Included 256 GB NVMe in M.2 slot 2: local backups (MySQL dumps + restic repo),
  # so a dead system disk doesn't take the backups with it
  disko.devices.disk.backup = {
    type = "disk";
    device = "/dev/disk/by-id/nvme-CHANGE-ME";
    content = {
      type = "gpt";
      partitions.backup = {
        size = "100%";
        content = {
          type = "btrfs";
          extraArgs = [ "-f" ];
          mountpoint = "/var/backup";
          mountOptions = [
            "compress=zstd"
            "noatime"
          ];
        };
      };
    };
  };
}
