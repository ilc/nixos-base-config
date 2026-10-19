# System services configuration
{ config, pkgs, lib, hostname, isIntel, isLaptop, ... }:

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

    # Intel thermal management (Intel hosts only)
    thermald.enable = isIntel;

    # Power management
    power-profiles-daemon.enable = true;

    # Laptops: shut down cleanly on a flat battery instead of running until the
    # cells cut out mid-write. PowerOff, not Hibernate: kraken/thunder/owl have
    # no swap, and no host sets a resume device.
    upower = lib.mkIf isLaptop {
      enable = true;
      percentageLow = 15;
      percentageCritical = 7;
      percentageAction = 5;
      criticalPowerAction = "PowerOff";
    };

    # Tailscale mesh VPN. `tailscale up` (once, per host) does the auth.
    tailscale.enable = true;
  };

  # Udev rules: keyboards (Via, Vial), plus a lock on security keys. via's
  # packaged rule makes every hidraw node 0666; YubiKeys are pinned back to
  # root-owned, no "other" access, with an ACL for the active console user
  # (uaccess); := stops that later rule from widening them. 0660, not 0600:
  # the group bits are the ACL mask, and 0600 would void the user's ACL. Sorts before 73-seat-late, which
  # applies uaccess.
  services.udev.packages = with pkgs; [
    vial
    via
    (writeTextDir "lib/udev/rules.d/70-yubikey-lock.rules" ''
      SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1050", GROUP:="root", MODE:="0660", TAG+="uaccess"
    '')
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
  #
  # USB power checker (2e88:c2c2), and the same device waiting for a firmware
  # update (2e3c:5780): group "users" can open both.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="0765", ATTR{idProduct}=="5020", MODE="0660", TAG+="uaccess"
    SUBSYSTEM=="usb", ATTR{idVendor}=="2e88", ATTR{idProduct}=="c2c2", MODE="0660", GROUP="users"
    SUBSYSTEM=="usb", ATTR{idVendor}=="2e3c", ATTR{idProduct}=="5780", MODE="0660", GROUP="users"
  '';

  # Flatpak support packages
  environment.systemPackages = with pkgs; [
    flatpak-builder
  ];
}
