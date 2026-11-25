{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    ./network.nix
    ./incus.nix
    ../../services/tailscale.nix
    ../../services/tsnsrv.nix
    ../../services/pihole.nix
    ../../services/gitea.nix
    ../../services/glance.nix
    ../../services/bentopdf.nix
    ../../services/backup.nix
  ];

  # Shared by the service modules
  _module.args.tailnet = "welara-turtle.ts.net";

  networking.hostName = "hestia";
  time.timeZone = "Europe/Amsterdam";
  i18n.defaultLocale = "en_US.UTF-8";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [ "root" ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILX693dWRTDMFdCzdmmRGG/ZTjKRPqeOt/DXajkicjKB maarten@prometheus"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICyjQYrZQY4PdQHC7/60s9fGLrHS0pYSdI3kVa5L1y6R maarten@mbp.local"
  ];

  sops = {
    defaultSopsFile = ../../../secrets/hestia.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };

  # What roles/update installed on every LXC
  environment.systemPackages = with pkgs; [
    curl
    eza
    fzf
    git
    jq
    lazygit
    neovim
    zoxide
  ];

  system.stateVersion = "26.05";
}
