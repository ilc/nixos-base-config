# Home-manager modules entry point
{ config, pkgs, lib, hostname, ... }:

{
  imports = [
    ./shell.nix
    ./git.nix
    ./editors.nix
    ./sway.nix
    ./niri.nix
    ./waybar.nix
    ./ghostty.nix
    ./kanshi.nix
    ./idle.nix
    ./color-calibration.nix
    ./tmux.nix
    ./firefox.nix
    ./chromium.nix
    ./packages.nix
    ./pi.nix
  ];

  # Core home-manager settings
  home.username = "ira";
  home.homeDirectory = "/home/ira";
  home.stateVersion = "23.05";

  # Let home-manager manage itself
  programs.home-manager.enable = true;

  # Enable fontconfig
  fonts.fontconfig.enable = true;

  # Session variables
  home.sessionVariables = {
    EDITOR = "nvim";
    # Disable pay-respects AI features
    _PR_AI_DISABLE = "";
    # OLED: force GTK apps (incl. chromium chrome) to use dark theme
    GTK_THEME = "Adwaita:dark";
  };

  # XDG directories
  xdg.enable = true;

  # Tell portal-aware apps to prefer dark color scheme (OLED + chromium chrome)
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };
}
