# Hardware configuration for bear (Intel laptop)
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.initrd.availableKernelModules = [ "xhci_pci" "thunderbolt" "nvme" "uas" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # LUKS encryption
  boot.initrd.luks.devices = {
    "luks-f7676a85-d4ff-4960-bb83-3f5f7eff20d7".device = "/dev/disk/by-uuid/f7676a85-d4ff-4960-bb83-3f5f7eff20d7";
    "luks-8c0d564d-2893-4e17-bfe4-aa4c4b34a190".device = "/dev/disk/by-uuid/8c0d564d-2893-4e17-bfe4-aa4c4b34a190";
  };

  # Filesystems
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/14f69658-c461-4369-86c7-fbff9f45fa1a";
    fsType = "btrfs";
    options = [ "subvol=@" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/4828-D586";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  swapDevices = [
    {
      device = "/dev/mapper/luks-8c0d564d-2893-4e17-bfe4-aa4c4b34a190";
      priority = 2;
    }
  ];

  # Networking
  networking.hostName = "bear";
  networking.useDHCP = lib.mkDefault true;

  # Platform
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
