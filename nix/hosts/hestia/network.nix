# The LAN NIC is enslaved to br0; Incus guests (HAOS) bridge onto it and get LAN IPs
# from the router, just like vmbr0 on Proxmox.
{
  networking = {
    useNetworkd = true;
    useDHCP = false;
    nftables.enable = true; # required by Incus
    # Pi-hole answers locally; the fallback covers boot and Pi-hole outages
    nameservers = [
      "127.0.0.1"
      "9.9.9.9"
    ];
  };

  # Its stub listener would clash with Pi-hole on :53
  services.resolved.enable = false;

  systemd.network = {
    enable = true;
    netdevs."10-br0".netdevConfig = {
      Kind = "bridge";
      Name = "br0";
    };
    networks."10-lan-uplink" = {
      matchConfig.Name = "en*"; # pin to the real NIC (MACAddress=) if the box has more than one
      networkConfig.Bridge = "br0";
      linkConfig.RequiredForOnline = "enslaved";
    };
    networks."20-br0" = {
      matchConfig.Name = "br0";
      # .10 stays with the old Proxmox host during the parallel run
      address = [ "192.168.1.11/24" ];
      gateway = [ "192.168.1.1" ];
      linkConfig.RequiredForOnline = "routable";
    };
  };
}
