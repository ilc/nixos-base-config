# Hardware configuration for owl (Lenovo ThinkPad X1, Intel Comet Lake i7-10710U, 16GB)
# Generated on owl via nixos-generate-config; UUIDs/modules are owl-specific.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # LUKS root (owl was installed via the NixOS graphical installer → LUKS + a
  # GRUB-style ESP at /boot/efi). The shared modules/system uses systemd-boot,
  # so point it at owl's existing ESP below (efiSysMountPoint).
  boot.initrd.luks.devices."luks-aa8f6189-4593-4ebe-8891-8d9945379f72".device =
    "/dev/disk/by-uuid/aa8f6189-4593-4ebe-8891-8d9945379f72";

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/9875678a-72b7-4aa7-b82b-193c8b5ba1e0";
    fsType = "btrfs";
    options = [ "subvol=@" ];
  };

  fileSystems."/boot/efi" = {
    device = "/dev/disk/by-uuid/AAE7-39DE";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };

  # owl's ESP is at /boot/efi (installer layout), not the systemd-boot default /boot.
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  # owl's ESP is a small installer-sized partition — the shared default of 10
  # systemd-boot generations can overflow it. Cap owl at 5. mkForce overrides
  # the shared configurationLimit = 10 in modules/system/default.nix.
  boot.loader.systemd-boot.configurationLimit = lib.mkForce 5;

  swapDevices = [ ];

  networking.hostName = "owl";
  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
