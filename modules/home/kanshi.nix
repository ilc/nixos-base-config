# Kanshi display configuration
{ config, pkgs, lib, hostname, ... }:

{
  services.kanshi = {
    enable = true;

    # Kanshi is first-match-wins. Order profiles MOST-SPECIFIC FIRST so the
    # docked profiles take precedence when all outputs are connected; the
    # bare-laptop profile only matches when no externals are present.
    settings = [
      # Docked: laptop (bear/thunder) with dual LG 4K via Dell TB dock + KVM.
      # eDP-1 MUST be disabled or the dock link runs out of bandwidth.
      {
        profile = {
          name = "bear-desk";
          outputs = [
            {
              criteria = "eDP-1";
              status = "disable";
            }
            {
              criteria = "LG Electronics LG ULTRAGEAR+ 503NTXR3M946";
              status = "enable";
              position = "0,0";
              scale = 1.5;
              mode = "3840x2160@60Hz";
            }
            {
              criteria = "LG Electronics LG ULTRAGEAR+ 510RMYA9R506";
              status = "enable";
              position = "2560,0";
              scale = 1.5;
              mode = "3840x2160@60Hz";
            }
          ];
        };
      }

      # Slime (AMD desktop) — no eDP, just the two LGs.
      # Left = 503NTXR3M946 (new replacement), Right = 510RMYA9R506 (eval,
      # kept free). Original 510RMKU22925 returned to Amazon.
      # Color: LG hardware calibration (in-panel) is the plan; software VCGT
      # loader is being retired, so neither has a repo ICC going forward.
      # 144.050Hz: verified working on slime's link; matches the Windows-side
      # reliability choice (240 is capable but overkill).
      {
        profile = {
          name = "slime-kvm";
          outputs = [
            {
              criteria = "LG Electronics LG ULTRAGEAR+ 503NTXR3M946";
              status = "enable";
              position = "0,0";
              scale = 1.5;
              mode = "3840x2160@144.050Hz";
            }
            {
              criteria = "LG Electronics LG ULTRAGEAR+ 510RMYA9R506";
              status = "enable";
              position = "2560,0";
              scale = 1.5;
              mode = "3840x2160@144.050Hz";
            }
          ];
        };
      }

      # Laptop alone (eDP-1 only). Scale is per-host:
      #   thunder = 2.0 (Samsung 3200x2000 panel)
      #   bear    = 1.75
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
    ];
  };

  home.packages = with pkgs; [
    kanshi
  ];
}
