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
    ./foot.nix
    ./kanshi.nix
    ./packages.nix
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
  };

  # XDG directories
  xdg.enable = true;
}
