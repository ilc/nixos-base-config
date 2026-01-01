{ config, pkgs, lib, ... }: {
  # Core System Configuration
  system.stateVersion = "22.11";
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  security.sudo.wheelNeedsPassword = false;
  nixpkgs.config.allowUnfree = true;
  documentation.dev.enable = true;
  hardware.enableRedistributableFirmware = true;
  services.flatpak.enable = true;


  # Boot and Hardware
  imports = [
  ./hardware-configuration.nix  # This line must be present
  ];

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi = {
        canTouchEfiVariables = true;
      };
    };
    # Kernel Modules
    extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback.out ];
    kernelModules = [ "v4l2loopback" "snd-aloop" "dummy" ];
    extraModprobeConfig = ''
      options kvm_intel nested=1 v4l2loopback exclusive_caps=1 card_label="Virtual Camera"
    '';
  };

  # Hardware Configuration
  hardware = {
    bluetooth.enable = true;
    pulseaudio.enable = false;
    opengl = {
      enable = true;
      driSupport32Bit = true;
    };
  };

  # Networking
  networking = {
    networkmanager.enable = true;
    enableIPv6 = false;
    interfaces.lo.ipv4.addresses = [
      { address = "172.17.0.1"; prefixLength = 32; }
    ];
  };

  # Localization and Time
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

  # Display and Window Management
  services.xserver = {
    enable = true;
    layout = "us";
    xkbVariant = "";
    displayManager.gdm = {
      enable = true;
      wayland = true;
    };
  };

  services.hardware.bolt.enable = true;

  programs = {
    sway = {
      enable = true;
      extraOptions = [ "--unsupported-gpu" ];
    };
#    niri.enable = true;
    zsh.enable = true;
    nix-ld.enable = true;
    seahorse.enable = true;
  };

  # Audio and Media
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };
    pulse.enable = true;
  };

  # Virtualization
  virtualisation = {
    podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };
    libvirtd.enable = true;
  };

  # System Services
  services = {
    fwupd.enable = true;
    pcscd.enable = true;
    printing.enable = true;
    blueman.enable = true;
    dbus.enable = true;
    openssh = {
      enable = true;
      passwordAuthentication = true;
    };
  };

  # User Configuration
  users.users.ira = {
    isNormalUser = true;
    shell = pkgs.zsh;
    description = "Ira Cooper";
    extraGroups = [ "networkmanager" "wheel" "libvirtd" "input" ];
    packages = with pkgs; [
      firefox
      neovim
      libva-utils
    ];
  };
programs.xwayland = {
  enable = lib.mkForce true;  # Force enable XWayland for both
};

  # Environment Configuration
  environment = {
    shells = [ pkgs.zsh ];
    sessionVariables = {
      NIXOS_OZONE_WL = "1";
      XDG_SESSION_TYPE = "wayland";
    };
    systemPackages = with pkgs; [
      neovim
      vim
      man-pages
      man-pages-posix
      pcscliteWithPolkit.out
      via
      vial
      virtiofsd
      wineWowPackages.stable
      winetricks
      wineWowPackages.waylandFull
      flatpak-builder
      xwayland-satellite
    ];
    pathsToLink = [ "/share/wayland-sessions" ];
    etc = {
      "wayland-sessions/sway.desktop".text = ''
        [Desktop Entry]
        Name=Sway
        Comment=An i3-compatible Wayland compositor
        Exec=sway
        Type=Application
      '';
      "wayland-sessions/niri.desktop".text = ''
        [Desktop Entry]
        Name=niri
        Comment=A scrollable-tiling Wayland compositor
        Exec=niri
        Type=Application
      '';
    };
  };

  # XDG Portal Configuration
  xdg.portal = {
    enable = true;

    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-wlr
    ];
    # Explicitly override wlr.enable
    wlr.enable = lib.mkForce true;
    config = {
      common.default = "*";
      sway = {
        default = lib.mkForce "wlr";
        "org.freedesktop.impl.portal.Screenshot" = "wlr";
        "org.freedesktop.impl.portal.Screencast" = "wlr";
      };
#      niri = {
#        default = "wlr";
#        "org.freedesktop.impl.portal.Screenshot" = "wlr";
#        "org.freedesktop.impl.portal.Screencast" = "wlr";
#      };
    };
    xdgOpenUsePortal = true;
  };

#  nixpkgs.config.allowUnfree = true;

  # Device Rules
  services.udev.packages = with pkgs; [
    vial
    via
  ];
}

