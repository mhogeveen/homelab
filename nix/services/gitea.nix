# Native Gitea on SQLite (/var/lib/gitea/data/gitea.db). It only hosts a few mirrors, so it
# was set up fresh instead of migrating the old MySQL container.
{
  config,
  lib,
  tailnet,
  ...
}:
{
  # `gitea admin ...` on the host (the module doesn't put the CLI on PATH)
  environment.systemPackages = [ config.services.gitea.package ];

  services.gitea = {
    enable = true;
    database.type = "sqlite3";
    settings = {
      server = {
        DOMAIN = "gitea.${tailnet}";
        ROOT_URL = "https://gitea.${tailnet}/";
        HTTP_ADDR = "127.0.0.1";
        HTTP_PORT = 3000;
        # tsnsrv only proxies HTTP, so SSH goes through the host's own node:
        #   ssh://git@hestia.<tailnet>:222/<owner>/<repo>.git
        START_SSH_SERVER = true;
        SSH_DOMAIN = "hestia.${tailnet}";
        SSH_PORT = 222;
        SSH_LISTEN_PORT = 222;
      };
      service = {
        DISABLE_REGISTRATION = true;
        # Nothing is visible without logging in, public repos included
        REQUIRE_SIGNIN_VIEW = true;
      };
      session.COOKIE_SECURE = true;
    };
  };

  # The built-in SSH server binds a port < 1024. PrivateUsers must be off: inside a user
  # namespace the capability doesn't cover the host's ports ("bind: permission denied").
  systemd.services.gitea.serviceConfig = {
    AmbientCapabilities = lib.mkForce "CAP_NET_BIND_SERVICE";
    CapabilityBoundingSet = lib.mkForce "CAP_NET_BIND_SERVICE";
    PrivateUsers = lib.mkForce false;
  };

  networking.firewall.allowedTCPPorts = [ 222 ];
}
