# Kanshi display configuration
{ config, pkgs, lib, hostname, ... }:

{
  services.kanshi = {
    enable = true;

    settings = [
      # Laptop alone (eDP-1 only). Scale is per-host:
      #   thunder = 2.0 (4K panel)
      #   bear    = 1.75 (TBD — adjust once verified on the device)
      {
        profile = {
          name = "laptop";
          outputs = [
            {
              criteria = "eDP-1";
              status = "enable";
              scale = if hostname == "thunder" then 2.0 else 1.75;
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
