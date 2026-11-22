# One tailnet node per service, so the existing https://<name>.<tailnet> URLs keep working.
# Remove the old LXC's machine from the tailnet admin console BEFORE a node first
# starts here, otherwise Tailscale hands out "<name>-1".
{ config, ... }:
{
  # Reusable auth key (pre-approved; tagged keys also skip key expiry)
  sops.secrets.tsnsrv_authkey = { };

  services.tsnsrv = {
    enable = true;
    defaults.authKeyPath = config.sops.secrets.tsnsrv_authkey.path;
    services = {
      gitea.toURL = "http://127.0.0.1:3000";
      glance.toURL = "http://127.0.0.1:8080";
      pi-hole.toURL = "http://127.0.0.1:8081";
      bentopdf.toURL = "http://127.0.0.1:3001";
    };
  };
}
