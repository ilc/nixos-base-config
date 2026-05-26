# Idle / DPMS — OLED burn-in protection
{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [ wlopm ];

  services.swayidle = {
    enable = true;
    systemdTarget = "graphical-session.target";

    timeouts = [
      # Power off displays after 5 minutes idle (lets OLED panel run its
      # compensation cycle in DPMS-off state; lock is manual, not auto).
      {
        timeout = 300;
        command = "${pkgs.wlopm}/bin/wlopm --off '*'";
        resumeCommand = "${pkgs.wlopm}/bin/wlopm --on '*'";
      }
    ];

    events = [
      # Re-power displays on resume from suspend
      {
        event = "after-resume";
        command = "${pkgs.wlopm}/bin/wlopm --on '*'";
      }
    ];
  };
}
