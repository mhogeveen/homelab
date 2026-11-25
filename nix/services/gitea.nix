# Native Gitea on MySQL 8 (matches the old mysql:8 container, so the dump imports cleanly).
# createDatabase uses socket auth, so no database password is needed anymore.
{
  lib,
  pkgs,
  tailnet,
  ...
}:
{
  services.mysql.package = pkgs.mysql84;

  services.gitea = {
    enable = true;
    database = {
      type = "mysql";
      createDatabase = true;
    };
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
      service.DISABLE_REGISTRATION = true;
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
