# Incus only hosts the HAOS VM (created imperatively, see docs/migration.md) and
# provides the web UI at https://hestia.<tailnet>:8443.
# Preseed only creates/updates; it never deletes anything it once created.
{
  virtualisation.incus = {
    enable = true;
    ui.enable = true;
    preseed = {
      config."core.https_address" = ":8443";
      # No Incus-managed network: its dnsmasq would fight Pi-hole for :53
      networks = [ ];
      storage_pools = [
        {
          name = "default";
          driver = "btrfs";
          config.source = "/var/lib/incus-pool";
        }
      ];
      profiles = [
        {
          name = "default";
          devices = {
            eth0 = {
              name = "eth0";
              type = "nic";
              nictype = "bridged";
              parent = "br0";
            };
            root = {
              path = "/";
              pool = "default";
              type = "disk";
            };
          };
        }
      ];
    };
  };

  # UI/API only reachable over Tailscale
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 8443 ];
}
