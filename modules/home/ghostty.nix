# Ghostty terminal configuration
{ config, pkgs, lib, ... }:

{
  programs.ghostty = {
    enable = true;
    enableBashIntegration = true;

    settings = {
      font-family = "JetBrainsMono Nerd Font";
      font-size = 9;

      scrollback-limit = 10000000;

      background = "000000";
      foreground = "ffffff";

      # Colorblind-friendly red remapping
      palette = [
        "1=#ff6432"  # red → red-orange
        "9=#ff55c8"  # bright red → hot pink
      ];
    };
  };
}
