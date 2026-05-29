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

      # Cursor: solid block, dimmed color. Block matches the convention
      # (hollow = unfocused, solid = focused); a single cell at #bbbbbb is
      # negligible OLED area vs the visibility win.
      cursor-style = "block";
      cursor-color = "bbbbbb";
      # Shell integration forces a bar cursor at the prompt by default,
      # overriding cursor-style. Disable just the cursor part of shell
      # integration so our underline setting actually applies.
      shell-integration-features = "no-cursor";

      # Colorblind-friendly red remapping
      palette = [
        "1=#ff6432"  # red → red-orange
        "9=#ff55c8"  # bright red → hot pink
      ];
    };
  };
}
