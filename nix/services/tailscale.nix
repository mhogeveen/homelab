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
    # Tailscale SSH: ssh over the tailnet is authorized by the tailnet policy's `ssh`
    # rules, not by OpenSSH keys (LAN ssh still goes to OpenSSH). extraSetFlags runs on
    # every start, unlike extraUpFlags, which only applies at the first login.
    extraSetFlags = [ "--ssh" ];
  };
}
