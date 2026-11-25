{
  description = "Homelab";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # one tailnet node (+ HTTPS cert) per service, keeps the <name>.<tailnet>.ts.net URLs
    tsnsrv = {
      url = "github:boinkor-net/tsnsrv";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      disko,
      sops-nix,
      tsnsrv,
      ...
    }:
    let
      # hestia's platform plus the workstations that deploy it
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
    in
    {
      # Replaces the Proxmox host 'proxmox' (Beelink SEi13)
      nixosConfigurations.hestia = nixpkgs.lib.nixosSystem {
        modules = [
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
          tsnsrv.nixosModules.default
          ./nix/hosts/hestia
        ];
      };

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);

      devShells = forAllSystems (system: {
        default = nixpkgs.legacyPackages.${system}.mkShell {
          packages = with nixpkgs.legacyPackages.${system}; [
            ansible # still used for the NAS and its LXCs
            just
            nixos-anywhere
            nixos-rebuild-ng # for `just deploy` from macOS
            sops
            ssh-to-age
          ];
        };
      });
    };
}
