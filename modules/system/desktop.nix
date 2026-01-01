# Desktop environment configuration (Wayland, Sway, Niri, GDM)
{ config, pkgs, lib, ... }:

{
  # Display manager
  services.xserver = {
    enable = true;
    xkb = {
      layout = "us";
      variant = "";
    };
  };

  services.displayManager.gdm = {
    enable = true;
    wayland = true;
  };

  # Sway
  programs.sway = {
    enable = true;
    extraOptions = [ "--unsupported-gpu" ];
  };

  # Niri
  programs.niri.enable = true;

  # XWayland
  programs.xwayland.enable = lib.mkForce true;

  # Seahorse for keyring management
  programs.seahorse.enable = true;

  # Thunderbolt
  services.hardware.bolt.enable = true;

  # Environment variables
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    XDG_SESSION_TYPE = "wayland";
  };

  # Wayland session entries
  environment.pathsToLink = [ "/share/wayland-sessions" ];
  environment.etc = {
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
      Exec=niri-session
      Type=Application
    '';
  };

  # XDG Portal configuration
  xdg.portal = {
    enable = true;
    wlr.enable = lib.mkForce true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-wlr
    ];
    config = {
      common.default = "*";
      sway = {
        default = lib.mkForce "wlr";
        "org.freedesktop.impl.portal.Screenshot" = "wlr";
        "org.freedesktop.impl.portal.Screencast" = "wlr";
      };
      niri = {
        default = lib.mkForce "wlr";
        "org.freedesktop.impl.portal.Screenshot" = "wlr";
        "org.freedesktop.impl.portal.Screencast" = "wlr";
      };
    };
    xdgOpenUsePortal = true;
  };

  # Desktop packages
  environment.systemPackages = with pkgs; [
    xwayland-satellite
    appimage-run
  ];
}
