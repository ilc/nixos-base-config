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

  # Udev rules: keyboards (Via, Vial)
  services.udev.packages = with pkgs; [
    vial
    via
  ];

  # Calibrite Display Pro HL / X-Rite i1 Display Pro (USB 0765:5020).
  # NixOS rejects argyllcms's packaged rules (they call usb_id by relative
  # path), so write the rule directly. TAG+="uaccess" gives the logged-in
  # user access via logind — no group membership needed.
  #
  # Match the top-level usb_device node (SUBSYSTEM/ATTR singular + DEVTYPE),
  # not parent devices (SUBSYSTEMS/ATTRS plural). The plural form can land
  # the uaccess tag on the wrong node, so the ACL applies inconsistently on
  # re-enumeration (e.g. after a KVM USB switch gives the meter a new node).
  # ACTION=="add" ensures it fires on every (re)attach.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="0765", ATTR{idProduct}=="5020", MODE="0660", TAG+="uaccess"
  '';

  # Flatpak support packages
  environment.systemPackages = with pkgs; [
    flatpak-builder
  ];
}
