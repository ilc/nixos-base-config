# System services configuration
{ config, pkgs, lib, hostname, ... }:

{
  services = {
    # Firmware updates
    fwupd.enable = true;

    # Smart card daemon (YubiKey etc)
    pcscd.enable = true;

    # Printing
    printing.enable = true;

    # Bluetooth manager
    blueman.enable = true;

    # D-Bus
    dbus.enable = true;

    # SSH
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = true;
      };
    };

    # Flatpak
    flatpak.enable = true;

    # SSD TRIM
    fstrim = {
      enable = true;
      interval = "weekly";
    };

    # File indexing (locate command)
    locate = {
      enable = true;
      package = pkgs.plocate;
    };

    # Intel thermal management (Intel laptops only)
    thermald.enable = (hostname == "thunder" || hostname == "bear");

    # Power management
    power-profiles-daemon.enable = true;
  };

  # Udev rules for keyboards (Via, Vial)
  services.udev.packages = with pkgs; [
    vial
    via
  ];

  # Flatpak support packages
  environment.systemPackages = with pkgs; [
    flatpak-builder
  ];
}
