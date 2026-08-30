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
    ./tmux.nix
    ./firefox.nix
    ./chromium.nix
    ./packages.nix
    ./pi.nix
    ./cache-capture.nix
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
    # Allow unfree in impure CLI eval: channel commands (nix-shell/-build/-env)
    # and `--impure` flake commands. Pure `nix run nixpkgs#unfree` still needs
    # --impure (flakes ignore env + config.nix). Paired with config.nix below.
    NIXPKGS_ALLOW_UNFREE = "1";
    # Disable pay-respects AI features
    _PR_AI_DISABLE = "";
    # OLED: force GTK apps (incl. chromium chrome) to use dark theme
    GTK_THEME = "Adwaita:dark";
  };

  # XDG directories
  xdg.enable = true;

  # Durable unfree for the Nix CLI's impure eval: the canonical user config file,
  # honored by channel commands (nix-shell -p / nix-build / nix-env). Pure flake
  # commands (nix run nixpkgs#unfree) do not read it — they need --impure or a
  # registry-override flake; see NIXPKGS_ALLOW_UNFREE above.
  xdg.configFile."nixpkgs/config.nix".text = "{ allowUnfree = true; }\n";

  # Tell portal-aware apps to prefer dark color scheme (OLED + chromium chrome)
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };
}
