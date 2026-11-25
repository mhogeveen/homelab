# HP ProDesk 600 G6 DM: 256 GB NVMe (system) + 1 TB SATA HDD (backups). Find the ids
# with `ls -l /dev/disk/by-id/` on the installer.
{
  # Included 256 GB NVMe: boot + system + Incus pool (HAOS). ~75 GB used today
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/disk/by-id/nvme-CHANGE-ME";
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

  # 1 TB 2.5" SATA HDD in the drive bay: local backups (MySQL dumps + restic repo),
  # so a dead system disk doesn't take the backups with it
  disko.devices.disk.backup = {
    type = "disk";
    device = "/dev/disk/by-id/ata-CHANGE-ME";
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
