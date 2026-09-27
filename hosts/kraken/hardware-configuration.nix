# Hardware configuration for kraken (HP ZBook Ultra G1a — AMD Strix Halo laptop, 128GB)
# Modeled on hosts/slime (same SoC family), with laptop + G1a divergences.
# Device UUIDs from nixos-generate-config on the box (2026-09-26).
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Kernel — latest, like the rest of the fleet (Strix Halo is fully mainlined there)
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # i2c_hid_acpi: in case the built-in keyboard is i2c-HID rather
  # than PS/2 — the LUKS passphrase is typed in the initrd, so it must work there.
  # (pinctrl_amd, which it needs, is built into the kernel — not a module.)
  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "thunderbolt" "uas" "sd_mod" "i2c_hid_acpi" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  # GTT: no manual sizing — let amdgpu auto-size (slime pins 128GiB for its LLM
  # server; kraken doesn't need to).
  # DIVERGENCE FROM SLIME: IOMMU left on (slime sets amd_iommu=off) — this is a
  # Thunderbolt laptop, keep IOMMU for DMA protection on the TB/USB4 ports.
  boot.kernelParams = [ ];

  # LUKS2 root. The shipped SK hynix PC801 is TCG Pyrite (locking, NO media
  # encryption), so Opal/DriveLock can't do this job — dm-crypt does.
  # AES-256-XTS benches ~7.4 GiB/s/core here, faster than the drive.
  # bypassWorkqueues: skip dm-crypt's kcryptd queues (latency win on NVMe).
  boot.initrd.luks.devices."cryptroot" = {
    device = "/dev/disk/by-uuid/e6a861c9-bdff-4aee-a7c5-bd6cdbf46061";
    allowDiscards = true;
    bypassWorkqueues = true;
  };

  # Uncompressed to start: small-file writes on NVMe measured slower with zstd.
  # Benchmark before enabling (per-dir via `btrfs property set <dir> compression`).
  # noatime: no metadata writes on reads (small-file heavy workload).
  fileSystems."/" = {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    options = [ "subvol=@" "noatime" ];
  };

  fileSystems."/home" = {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    options = [ "subvol=@home" "noatime" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/A0FE-8DDC";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  swapDevices = [ ];

  # Networking
  networking.hostName = "kraken";
  networking.useDHCP = lib.mkDefault true;

  # Platform
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # Kraken-specific packages (AMD Strix Halo). Inference runtime only for
  # occasional on-box work — slime's persistent llama-server stays slime-scoped.
  environment.systemPackages = with pkgs; [
    ollama-vulkan
    radeontop    # GPU utilization
  ];

  # Thunderbolt / USB4 device authorization — dock peripherals need this.
  # After first dock connect: `boltctl enroll --policy=auto <dock-uuid>`.
  services.hardware.bolt.enable = true;

  # Key-only SSH on this laptop (base services.nix allows passwords globally;
  # a traveling box should not accept passwords on an open sshd).
  services.openssh.settings.PasswordAuthentication = lib.mkForce false;
}
