# Ungoogled-chromium — OLED-friendly defaults
{ config, pkgs, lib, ... }:

{
  programs.chromium = {
    enable = true;
    package = pkgs.ungoogled-chromium;

    commandLineArgs = [
      # Dark for chromium's internal pages only.
      # Avoid --force-dark-mode / WebContentsForceDark — they invert site
      # colors and break sites like Gmail. Browser chrome is darkened via
      # GTK_THEME + portal color-scheme in modules/home/default.nix.
      "--enable-features=WebUIDarkMode"
    ];
  };
}
