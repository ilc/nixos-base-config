# Kanshi display configuration
{ config, pkgs, lib, hostname, ... }:

{
  services.kanshi = {
    enable = true;

    settings = [
      # Laptop only (bear, thunder)
      {
        profile = {
          name = "laptop";
          outputs = [
            {
              criteria = "eDP-1";
              status = "enable";
              scale = 1.75;
            }
          ];
        };
      }

      # Bear at desk with dual LG ULTRAGEAR+ 4K monitors
      {
        profile = {
          name = "bear-desk";
          outputs = [
            {
              criteria = "eDP-1";
              status = "disable";
            }
            {
              criteria = "LG Electronics LG ULTRAGEAR+ 510RMKU22925";
              status = "enable";
              position = "0,0";
              scale = 1.5;
              mode = "3840x2160@144.050Hz";
            }
            {
              criteria = "LG Electronics LG ULTRAGEAR+ 408NTEP4T404";
              status = "enable";
              position = "2560,0";
              scale = 1.5;
              mode = "3840x2160@144.050Hz";
            }
          ];
        };
      }

      # Thunder (4K laptop) - normal mode
      # TODO: Adjust when thunder hardware-configuration is provided
      {
        profile = {
          name = "thunder-laptop";
          outputs = [
            {
              criteria = "eDP-1";
              status = "enable";
              scale = 2.0;  # 4K laptop needs higher scale
            }
          ];
        };
      }

      # Slime at KVM (same dual LG monitors as bear)
      # Since slime is AMD desktop, it likely has different output names
      # but kanshi matches by monitor serial, so this should work
      {
        profile = {
          name = "slime-kvm";
          outputs = [
            {
              criteria = "LG Electronics LG ULTRAGEAR+ 510RMKU22925";
              status = "enable";
              position = "0,0";
              scale = 1.5;
              mode = "3840x2160@144.050Hz";
            }
            {
              criteria = "LG Electronics LG ULTRAGEAR+ 408NTEP4T404";
              status = "enable";
              position = "2560,0";
              scale = 1.5;
              mode = "3840x2160@144.050Hz";
            }
          ];
        };
      }

      # Thunder at KVM (same dual LG monitors)
      # Capped at 60Hz: thunder's DP link can't sustain 2× 4K @ 144Hz, and
      # without an explicit cap the 510 will EDID-prefer 240Hz and starve
      # the second monitor of bandwidth.
      {
        profile = {
          name = "thunder-kvm";
          outputs = [
            {
              criteria = "eDP-1";
              status = "disable";
            }
            {
              criteria = "LG Electronics LG ULTRAGEAR+ 510RMKU22925";
              status = "enable";
              position = "0,0";
              scale = 1.5;
              mode = "3840x2160@60Hz";
            }
            {
              criteria = "LG Electronics LG ULTRAGEAR+ 408NTEP4T404";
              status = "enable";
              position = "2560,0";
              scale = 1.5;
              mode = "3840x2160@60Hz";
            }
          ];
        };
      }
    ];
  };

  home.packages = with pkgs; [
    kanshi
  ];
}
