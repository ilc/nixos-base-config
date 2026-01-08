# Hardware configuration for thunder (Intel laptop with 4K screen)
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.initrd.availableKernelModules = [ "xhci_pci" "thunderbolt" "nvme" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # Intel IPU6 camera (ov02c10 sensor) - Meteor Lake (PCI ID 0x7d19)
  # Kernel 6.16+ has mainline support; userspace needs HAL + bins
  environment.systemPackages = with pkgs; [
    ipu6-camera-bins
    ipu6epmtl-camera-hal
    gst_all_1.icamerasrc-ipu6epmtl
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/912fe001-3b01-4931-8b2f-056990599fdb";
    fsType = "btrfs";
    options = [ "subvol=@" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/A124-F808";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };

  swapDevices = [ ];

  # Networking
  networking.hostName = "thunder";
  networking.useDHCP = lib.mkDefault true;

  # Platform
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
