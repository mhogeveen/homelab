# The host's own tailnet node (hestia.<tailnet>): SSH, Incus UI, Gitea SSH.
# Web services get their own nodes via tsnsrv.nix.
{ config, ... }:
{
  sops.secrets.tailscale_authkey = { };

  services.tailscale = {
    enable = true;
    openFirewall = true;
    authKeyFile = config.sops.secrets.tailscale_authkey.path;
    # The host resolves through its own Pi-hole, not MagicDNS
    extraUpFlags = [ "--accept-dns=false" ];
  };
}
