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

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/89a5471f-348b-4d46-a90e-97c6508cd4ff";
    fsType = "btrfs";
    options = [ "subvol=@home" ];
  };

  # Throwaway build trees: a separate subvolume so they stay out of @home's
  # snapshots and backups.
  #
  # user_subvol_rm_allowed lets ira delete a build-tree subvolume without root
  # (instant, instead of rm -rf). btrfs applies it to the whole filesystem, not
  # this mount: an unprivileged delete still needs write access to the
  # subvolume's parent directory, and every system subvolume and snapshot sits
  # under a root-owned one, so in practice only subvolumes under
  # /scratch/<user>-owned directories are deletable this way.
  fileSystems."/scratch" = {
    device = "/dev/disk/by-uuid/89a5471f-348b-4d46-a90e-97c6508cd4ff";
    fsType = "btrfs";
    options = [ "subvol=@scratch" "noatime" "nofail" "user_subvol_rm_allowed" ];
  };

  systemd.tmpfiles.rules = [
    "d /scratch 0755 root root -"
    "d /scratch/ira 0700 ira users -"
    # Never backed up, whatever a backup's path list says.
    "f /scratch/.nobackup 0644 root root -"
  ];

  # Front USB ports: a built-in Genesys hub (USB2 half 3-2, USB3 half 4-2)
  # with real per-port power switching. Group users may open it, so uhubctl
  # can power-cycle a device for power-loss testing without root. Port power is
  # shared by both halves, so a real cut means switching the port off on both.
  # Matched by position as well as model, and only while it reports itself as
  # built in: the same chip turns up in docks and monitors, and the back ports'
  # hub (Realtek) carries the KVM, so neither must match. If the bus numbers
  # ever move, the rule stops matching rather than spreading to another hub.
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", KERNEL=="3-2", ATTR{idVendor}=="05e3", ATTR{idProduct}=="0610", ATTR{removable}=="fixed", MODE="0660", GROUP="users"
    SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", KERNEL=="4-2", ATTR{idVendor}=="05e3", ATTR{idProduct}=="0625", ATTR{removable}=="fixed", MODE="0660", GROUP="users"
  '';

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
