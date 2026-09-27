# System modules entry point
{ config, pkgs, lib, hostname, isIntel, isRamTight, ... }:

{
  imports = [
    ./desktop.nix
    ./audio.nix
    ./virtualization.nix
    ./services.nix
    ./llama-server.nix
    ./claude-code.nix
  ];

  # Core system settings
  system.stateVersion = "22.11";

  # Nix settings
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;

  # RAM-tight build boxes (isRamTight = thunder 32GB / owl 16GB) OOM under nix's
  # default max-jobs=auto, which fires a dozen parallel compiles into contended
  # RAM (thunder's nixos-rebuild OOM'd; owl at 16GB is tighter still). Cap
  # parallelism and add a zram safety net so a rebuild can't take the box down.
  # slime/bear/kraken are unconstrained. Override higher on the CLI when idle
  # (e.g. `--max-jobs 4 --cores 12`), or offload with `--build-host slime`.
  nix.settings.max-jobs = lib.mkIf isRamTight 1;  # one derivation at a time — no parallel heavy compiles
  nix.settings.cores = lib.mkIf isRamTight 4;     # threads within a build; bounds a single big compile/link
  zramSwap.enable = lib.mkIf isRamTight true;     # ~50% of RAM as compressed swap — OOM headroom under load
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  nixpkgs.config.allowUnfree = true;

  # Documentation
  documentation.dev.enable = true;

  # Security
  security.sudo.wheelNeedsPassword = false;
  security.rtkit.enable = true;
  security.polkit.enable = true;

  # Hardware
  hardware.enableRedistributableFirmware = true;
  hardware.bluetooth.enable = true;

  # Use hardware.graphics instead of deprecated hardware.opengl.
  # Intel hosts get iHD + oneVPL for VAAPI. Slime (Strix Halo / AMD) uses
  # mesa's radeonsi VAAPI which ships with mesa via hardware.graphics.enable —
  # do not shove Intel drivers into its closure.
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = lib.optionals isIntel
      (with pkgs; [
        intel-media-driver     # iHD; Gen9+ incl. Meteor Lake
        vpl-gpu-rt             # Intel oneVPL runtime (AV1/HEVC on Xe/Arc)
        libvdpau-va-gl         # VDPAU→VAAPI shim for legacy consumers
      ]);
  };

  # Point libva at iHD explicitly on Intel hosts.
  environment.sessionVariables.LIBVA_DRIVER_NAME = lib.mkIf isIntel "iHD";

  # Boot configuration (common to all hosts)
  boot = {
    loader = {
      systemd-boot.enable = true;
      systemd-boot.configurationLimit = 10;
      efi.canTouchEfiVariables = true;
    };
    # Video/audio loopback for OBS etc
    extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback.out ];
    kernelModules = [ "v4l2loopback" "snd-aloop" "dummy" ];
    extraModprobeConfig = ''
      options v4l2loopback exclusive_caps=1 card_label="Virtual Camera"
    '';
  };

  # Localization
  time.timeZone = "America/New_York";
  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };
  };

  # Networking
  networking = {
    networkmanager.enable = true;
    enableIPv6 = false;
    firewall.enable = true;
    firewall.allowedTCPPorts = lib.optionals (!builtins.elem hostname [ "thunder" "kraken" ]) [ 5174 ];
    interfaces.lo.ipv4.addresses = [
      { address = "172.17.0.1"; prefixLength = 32; }
    ];
  };

  # User configuration
  users.users.ira = {
    isNormalUser = true;
    shell = pkgs.bash;
    description = "Ira Cooper";
    extraGroups = [ "networkmanager" "wheel" "libvirtd" "input" "podman" "dialout" ];
  };

  # System packages (minimal - most go in home-manager)
  environment = {
    shells = [ pkgs.bash pkgs.zsh ];
    systemPackages = with pkgs; [
      vim
      neovim
      git
      man-pages
      man-pages-posix
      pcscliteWithPolkit.out
      virtiofsd

      # Hardware diagnostics
      pciutils      # lspci
      usbutils      # lsusb
      lshw          # lshw
      lsscsi        # lsscsi
      hwloc         # lstopo (CPU/memory topology)
      lm_sensors    # sensors (temperature, fan, voltage)
      dmidecode     # SMBIOS/system info
      smartmontools # S.M.A.R.T. disk monitoring
      nvme-cli      # NVMe management
      ethtool       # network interface info
      libva-utils   # vainfo (VAAPI driver probe)

      # System debugging
      strace
      iotop

      # Network diagnostics
      tcpdump
      traceroute
      whois

      # Core utilities
      curl
      wget
      rsync
      parted
    ];
  };

  # Keep zsh available as escape hatch
  programs.zsh.enable = true;

  # nix-ld for running unpatched binaries
  programs.nix-ld.enable = true;
}
