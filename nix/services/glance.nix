# Translated from roles/sync-files/files/glance/config/glance.yml.
# Glance's own ${VAR} syntax is escaped as \${VAR} in Nix strings.
{ config, tailnet, ... }:
let
  site = title: name: icon: {
    inherit title icon;
    url = "https://${name}.${tailnet}";
  };
in
{
  sops.templates."glance.env".content = ''
    PI_HOLE_PASSWORD=${config.sops.placeholder.pihole_password}
  '';

  services.glance = {
    enable = true;
    environmentFile = config.sops.templates."glance.env".path;
    settings = {
      server = {
        host = "127.0.0.1";
        port = 8080;
      };

      theme = {
        background-color = "240 21 15";
        contrast-multiplier = 1.2;
        primary-color = "217 92 83";
        positive-color = "115 54 76";
        negative-color = "347 70 65";
      };

      pages = [
        {
          name = "Home";
          hide-desktop-navigation = true;
          center-vertically = true;
          columns = [
            {
              size = "full";
              widgets = [
                {
                  type = "search";
                  autofocus = true;
                }
                {
                  type = "bookmarks";
                  groups = [
                    {
                      links = [
                        {
                          title = "ProxmoxVE Helper Scripts";
                          url = "https://community-scripts.github.io/ProxmoxVE/";
                        }
                        {
                          title = "Router Admin Console";
                          url = "http://192.168.1.1";
                        }
                        {
                          title = "Dashboard Icons";
                          url = "https://dashboardicons.com/icons";
                        }
                      ];
                    }
                  ];
                }
                {
                  type = "monitor";
                  cache = "1m";
                  title = "Services";
                  sites = [
                    # Replaces "Beelink SEi13" (Proxmox); Incus serves a self-signed cert
                    {
                      title = "hestia (Incus)";
                      url = "https://hestia.${tailnet}:8443";
                      icon = "di:nixos";
                      allow-insecure = true;
                    }
                    (site "UGREEN NASync DXP4800 Plus" "nas" "di:proxmox")
                    (site "Home Assistant" "homeassistant" "di:home-assistant")
                    (site "qBittorrent" "qbittorrent" "di:qbittorrent")
                    {
                      title = "Pi-hole";
                      url = "https://pi-hole.${tailnet}/admin";
                      icon = "di:pi-hole";
                    }
                    (site "Jellyfin" "jellyfin" "di:jellyfin")
                    (site "Gitea" "gitea" "di:gitea")
                    (site "BentoPDF" "bentopdf" "di:bentopdf")
                    (site "Syncthing Server" "syncthing" "di:syncthing")
                  ];
                }
                {
                  type = "split-column";
                  widgets = [
                    {
                      type = "dns-stats";
                      service = "pihole-v6";
                      # Same host now, no need to go through the tailnet
                      url = "http://127.0.0.1:8081";
                      password = "\${PI_HOLE_PASSWORD}";
                      hour-format = "24h";
                    }
                    {
                      type = "html";
                      source = ''
                        <div hidden>placeholder</div>
                      '';
                    }
                  ];
                }
              ];
            }
            {
              size = "small";
              widgets = [
                {
                  type = "clock";
                  hour-format = "24h";
                }
                {
                  type = "weather";
                  location = "Hilversum, The Netherlands";
                  units = "metric";
                  hour-format = "24h";
                }
                {
                  type = "repository";
                  cache = "1m";
                  repository = "mhogeveen/homelab";
                  pull-requests-limit = 5;
                  issues-limit = 3;
                  commits-limit = 3;
                }
                {
                  type = "repository";
                  cache = "1m";
                  repository = "mhogeveen/dotfiles";
                  pull-requests-limit = 5;
                  issues-limit = 3;
                  commits-limit = 3;
                }
                {
                  type = "custom-api";
                  title = "Random Fact";
                  cache = "1h";
                  url = "https://uselessfacts.jsph.pl/api/v2/facts/random";
                  template = ''
                    <p class="size-h4 color-paragraph">{{ .JSON.String "text" }}</p>
                  '';
                }
              ];
            }
          ];
        }
      ];
    };
  };
}
