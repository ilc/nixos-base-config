# Sway window manager configuration
{ config, pkgs, lib, ... }:

{
  wayland.windowManager.sway = {
    enable = true;
    systemd.enable = true;

    extraOptions = [ "--unsupported-gpu" ];

    config = {
      modifier = "Mod4";
      terminal = "foot";
      menu = "rofi -show run";

      defaultWorkspace = "workspace 1-1";

      # Appearance
      gaps = {
        inner = 0;
        outer = 0;
      };

      window = {
        border = 2;
        titlebar = false;
      };

      # Input
      input = {
        "*" = {
          xkb_layout = "us";
        };
      };

      # Keybindings
      keybindings = let
        mod = "Mod4";
      in {
        # Terminal
        "${mod}+Return" = "exec foot";
        "${mod}+u" = "exec foot";

        # Kill window
        "${mod}+Shift+q" = "kill";

        # Launcher
        "${mod}+d" = "exec rofi -show run";

        # Reload config
        "${mod}+Shift+c" = "reload";

        # Exit sway
        "${mod}+Shift+e" = "exec swaynag -t warning -m 'Exit sway?' -B 'Yes' 'swaymsg exit'";

        # Focus (vim keys)
        "${mod}+h" = "focus left";
        "${mod}+j" = "focus down";
        "${mod}+k" = "focus up";
        "${mod}+l" = "focus right";

        # Focus (arrow keys)
        "${mod}+Left" = "focus left";
        "${mod}+Down" = "focus down";
        "${mod}+Up" = "focus up";
        "${mod}+Right" = "focus right";

        # Move windows (vim keys)
        "${mod}+Shift+h" = "move left";
        "${mod}+Shift+j" = "move down";
        "${mod}+Shift+k" = "move up";
        "${mod}+Shift+l" = "move right";

        # Move windows (arrow keys)
        "${mod}+Shift+Left" = "move left";
        "${mod}+Shift+Down" = "move down";
        "${mod}+Shift+Up" = "move up";
        "${mod}+Shift+Right" = "move right";

        # Workspaces (workroom system: 1-1 through 1-10)
        "${mod}+1" = "workspace 1-1";
        "${mod}+2" = "workspace 1-2";
        "${mod}+3" = "workspace 1-3";
        "${mod}+4" = "workspace 1-4";
        "${mod}+5" = "workspace 1-5";
        "${mod}+6" = "workspace 1-6";
        "${mod}+7" = "workspace 1-7";
        "${mod}+8" = "workspace 1-8";
        "${mod}+9" = "workspace 1-9";
        "${mod}+0" = "workspace 1-10";

        # Move to workspace
        "${mod}+Shift+1" = "move container to workspace 1-1";
        "${mod}+Shift+2" = "move container to workspace 1-2";
        "${mod}+Shift+3" = "move container to workspace 1-3";
        "${mod}+Shift+4" = "move container to workspace 1-4";
        "${mod}+Shift+5" = "move container to workspace 1-5";
        "${mod}+Shift+6" = "move container to workspace 1-6";
        "${mod}+Shift+7" = "move container to workspace 1-7";
        "${mod}+Shift+8" = "move container to workspace 1-8";
        "${mod}+Shift+9" = "move container to workspace 1-9";
        "${mod}+Shift+0" = "move container to workspace 1-10";

        # Layout
        "${mod}+b" = "splith";
        "${mod}+v" = "splitv";
        "${mod}+s" = "layout toggle stacking";
        "${mod}+w" = "layout toggle tabbed";
        "${mod}+e" = "layout toggle split";
        "${mod}+f" = "fullscreen";
        "${mod}+Shift+space" = "floating toggle";
        "${mod}+space" = "focus mode_toggle";
        "${mod}+a" = "focus parent";

        # Toggle waybar
        "${mod}+t" = "exec killall -SIGUSR1 waybar";

        # Lock screen
        "${mod}+Shift+z" = "exec swaylock --color '#000000'";

        # Scratchpad
        "${mod}+Shift+minus" = "move scratchpad";
        "${mod}+minus" = "scratchpad show";

        # Move workspace to output
        "${mod}+Control+Left" = "move workspace to output left";
        "${mod}+Control+Right" = "move workspace to output right";

        # Move container to output
        "${mod}+Control+Shift+Left" = "move container to output left";
        "${mod}+Control+Shift+Right" = "move container to output right";

        # Resize mode
        "${mod}+r" = "mode resize";
      };

      modes = {
        resize = {
          "h" = "resize shrink width 10px";
          "j" = "resize grow height 10px";
          "k" = "resize shrink height 10px";
          "l" = "resize grow width 10px";
          "Left" = "resize shrink width 10px";
          "Down" = "resize grow height 10px";
          "Up" = "resize shrink height 10px";
          "Right" = "resize grow width 10px";
          "Return" = "mode default";
          "Escape" = "mode default";
        };
      };

      # Bar
      bars = [{
        command = "waybar";
      }];

      # Startup
      startup = [
        { command = "dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY SWAYSOCK XDG_CURRENT_DESKTOP"; }
        { command = "systemctl --user stop pipewire pipewire-media-session xdg-desktop-portal xdg-desktop-portal-wlr"; }
        { command = "systemctl --user start pipewire pipewire-media-session xdg-desktop-portal xdg-desktop-portal-wlr"; }
        { command = "blueman-applet"; }
        { command = "kanshi"; always = true; }
      ];
    };

    extraConfig = ''
      # Floating modifier
      floating_modifier Mod4 normal

      # Default border
      default_border pixel 2
    '';
  };

  # Sway-related packages
  home.packages = with pkgs; [
    swaylock
    swaybg
    rofi
    grim
    slurp
    wl-clipboard
  ];
}
