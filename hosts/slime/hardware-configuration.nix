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
    # The blank start for build trees: an empty subvolume, locked read-only
    # (below). Each user takes its own writable snapshot of it, kept in its
    # own directory on this filesystem, and builds its structure there; that
    # snapshot is its separation from every other user. ira owns it so the
    # snapshots' top directory is writable; /scratch being root's keeps the
    # account from removing it.
    "v /scratch/work 0700 ira users -"
  ];

  # Lock /scratch/work read-only once it exists. Only while it is still
  # empty: one that somehow gained content is left alone, for a person to
  # look at, rather than locked with the content inside.
  systemd.services.scratch-work-ro = {
    description = "Lock the empty /scratch/work subvolume read-only";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-tmpfiles-setup.service" ];
    requires = [ "systemd-tmpfiles-setup.service" ];
    unitConfig.RequiresMountsFor = [ "/scratch" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [ pkgs.btrfs-progs pkgs.coreutils pkgs.findutils ];
    script = ''
      b=/scratch/work
      [ "$(stat -c %i "$b")" = 256 ] || { echo "$b is not a subvolume root"; exit 1; }
      if [ "$(btrfs property get "$b" ro)" = "ro=true" ]; then exit 0; fi
      if [ -n "$(find "$b" -mindepth 1 -print -quit)" ]; then
        echo "$b is not empty; leaving it writable"; exit 1
      fi
      btrfs property set "$b" ro true
    '';
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
