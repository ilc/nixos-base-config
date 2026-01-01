# Foot terminal configuration
{ config, pkgs, lib, ... }:

{
  programs.foot = {
    enable = true;

    settings = {
      main = {
        font = "JetBrainsMono Nerd Font:size=9";
      };

      bell = {
        urgent = "yes";
        notify = "yes";
      };

      scrollback = {
        lines = 10000;
      };

      colors = {
        background = "000000";
        foreground = "ffffff";
      };
    };
  };
}
