# System modules entry point
{ config, pkgs, lib, hostname, ... }:

{
  imports = [
    ./desktop.nix
    ./audio.nix
    ./virtualization.nix
    ./services.nix
  ];

  # Core system settings
  system.stateVersion = "22.11";

  # Nix settings
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  # Documentation
  documentation.dev.enable = true;

  # Security
  security.sudo.wheelNeedsPassword = false;
  security.rtkit.enable = true;

  # Hardware
  hardware.enableRedistributableFirmware = true;
  hardware.bluetooth.enable = true;

  # Use hardware.graphics instead of deprecated hardware.opengl
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

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
    interfaces.lo.ipv4.addresses = [
      { address = "172.17.0.1"; prefixLength = 32; }
    ];
  };

  # User configuration
  users.users.ira = {
    isNormalUser = true;
    shell = pkgs.bash;
    description = "Ira Cooper";
    extraGroups = [ "networkmanager" "wheel" "libvirtd" "input" ];
  };

  # System packages (minimal - most go in home-manager)
  environment = {
    shells = [ pkgs.bash pkgs.zsh ];
    systemPackages = with pkgs; [
      vim
      neovim
      man-pages
      man-pages-posix
      pcscliteWithPolkit.out
      virtiofsd
    ];
  };

  # Keep zsh available as escape hatch
  programs.zsh.enable = true;

  # nix-ld for running unpatched binaries
  programs.nix-ld.enable = true;
}
