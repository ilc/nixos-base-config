# Hardware configuration for slime (AMD desktop)
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "thunderbolt" "usbhid" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];
  boot.kernelParams = [ "amd_iommu=off" "amdgpu.gttsize=131072" "ttm.pages_limit=33554432" ];

  # Filesystems
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/89a5471f-348b-4d46-a90e-97c6508cd4ff";
    fsType = "btrfs";
    options = [ "subvol=@" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/2F99-6DE7";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  swapDevices = [ ];

  # Slime-specific packages (AMD Strix Halo)
  environment.systemPackages = with pkgs; [
    ollama-vulkan
    radeontop    # GPU utilization
    lact         # GPU control (fan curves, power) - uses wheel group
  ];

  # CoreCtrl with polkit rules (adds corectrl group)
  programs.corectrl.enable = true;

  # Add user to corectrl group
  users.users.ira.extraGroups = [ "corectrl" ];

  # Networking
  networking.hostName = "slime";
  networking.useDHCP = lib.mkDefault true;

  # Platform
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
