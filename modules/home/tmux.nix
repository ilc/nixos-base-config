# Tmux — OLED-friendly defaults
{ config, pkgs, lib, ... }:

{
  programs.tmux = {
    enable = true;
    terminal = "tmux-256color";
    escapeTime = 10;
    historyLimit = 100000;
    keyMode = "vi";
    mouse = true;
    # Keep the socket in /tmp/tmux-$UID (tmux enforces 0700 there). The secure
    # socket moves it under $XDG_RUNTIME_DIR via TMUX_TMPDIR, which only login
    # shells see, so non-login shells (e.g. `ssh host tmux attach`) looked in
    # /tmp and found no server; the runtime dir also vanishes at last logout.
    secureSocket = false;

    extraConfig = ''
      # OLED: keep status off by default; toggle with prefix + b
      set -g status off
      bind b set -g status

      # When status IS on, make it very dim (no big bright bar across the bottom)
      set -g status-style "bg=#000000,fg=#666666"
      set -g status-left-style  "bg=#000000,fg=#666666"
      set -g status-right-style "bg=#000000,fg=#666666"
      set -g window-status-style          "bg=#000000,fg=#555555"
      set -g window-status-current-style  "bg=#000000,fg=#aa7744"
      set -g window-status-activity-style "bg=#000000,fg=#aa7744"
      set -g message-style "bg=#000000,fg=#cccccc"

      # Dim pane borders too (active pane subtly warm, inactive nearly black)
      set -g pane-border-style        "fg=#222222"
      set -g pane-active-border-style "fg=#553322"

      # True color
      set -ga terminal-overrides ",xterm-256color:Tc,*256col*:Tc,xterm-ghostty:Tc"
    '';
  };
}
