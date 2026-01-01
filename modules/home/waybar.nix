# Waybar configuration
{ config, pkgs, lib, ... }:

{
  programs.waybar = {
    enable = true;
    systemd.enable = false;  # Sway/niri manage waybar via their own startup
    style = builtins.readFile ./waybar-style.css;
  };

  # Sway config - read from JSON file to preserve unicode icons
  xdg.configFile."waybar/config".source = ./waybar-config-sway.json;

  # Niri config
  xdg.configFile."waybar/config-niri".source = ./waybar-config-niri.json;
}
