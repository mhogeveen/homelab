# No nixpkgs module; it's a static client-side app, so a pinned container is fine.
# Bump the tag deliberately (was :latest via Ansible's pull: always).
{
  virtualisation.podman.enable = true;
  virtualisation.oci-containers = {
    backend = "podman";
    containers.bentopdf = {
      image = "ghcr.io/alam00000/bentopdf-simple:v2.8.12";
      # 3000 is Gitea's; reached via tsnsrv (https://bentopdf.<tailnet>)
      ports = [ "127.0.0.1:3001:8080" ];
    };
  };
}
