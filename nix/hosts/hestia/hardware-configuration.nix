# HP ProDesk 600 G6 DM (i3-10100T). PLACEHOLDER until install, which regenerates it:
#   nixos-anywhere --generate-hardware-config nixos-generate-config \
#     ./nix/hosts/hestia/hardware-configuration.nix --flake .#hestia root@<ip>
# Filesystems come from disko.nix, so the generated file won't list them.
{ lib, ... }:
{
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.kernelModules = [ "kvm-intel" ];

  hardware.cpu.intel.updateMicrocode = lib.mkDefault true;
  hardware.enableRedistributableFirmware = true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
