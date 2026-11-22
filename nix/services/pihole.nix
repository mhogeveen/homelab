# Pi-hole v6 (FTL + web UI) with unbound as the recursive upstream, same as CT 102.
# Config is immutable on NixOS: adlists and local records live here, not in the UI.
{ config, ... }:
{
  sops.secrets.pihole_password = { };
  # FTL reads FTLCONF_* overrides from the environment; keeps the password out of the store
  sops.templates."pihole.env".content = ''
    FTLCONF_webserver_api_password=${config.sops.placeholder.pihole_password}
  '';
  systemd.services.pihole-ftl.serviceConfig.EnvironmentFile = config.sops.templates."pihole.env".path;

  services.unbound = {
    enable = true;
    resolveLocalQueries = false;
    settings.server = {
      interface = [ "127.0.0.1" ];
      port = 5335;
      access-control = [ "127.0.0.0/8 allow" ];
      harden-glue = true;
      harden-dnssec-stripped = true;
      use-caps-for-id = false;
      prefetch = true;
      edns-buffer-size = 1232;
    };
  };

  services.pihole-ftl = {
    enable = true;
    openFirewallDNS = true;
    queryLogDeleter.enable = true;
    lists = [
      {
        url = "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts";
        description = "Steven Black's unified hosts (Pi-hole default)";
      }
      # TODO: copy any extra adlists from the old Pi-hole (Settings > Lists)
    ];
    settings = {
      dns = {
        upstreams = [ "127.0.0.1#5335" ];
        # Answer LAN and tailnet clients; the router keeps :53 off the internet
        listeningMode = "ALL";
        domainNeeded = true;
        # TODO: copy Local DNS records from the old Pi-hole, e.g. "192.168.1.20 nas.lan"
        hosts = [ ];
      };
    };
  };

  services.pihole-web = {
    enable = true;
    # Reached via tsnsrv (https://pi-hole.<tailnet>/admin)
    ports = [ "127.0.0.1:8081" ];
  };
}
