# Idle / DPMS — OLED burn-in protection
{ config, pkgs, lib, ... }:

let
  # Wake script: a full disable→enable modeset, not a soft power toggle.
  # Through the KVM, `output * power on` reports success but never retrains
  # the DP link, so deep-slept panels stay dark (sway's view and the panel's
  # physical state disagree). disable→enable forces a real modeset — the same
  # effect as switching KVM inputs — which wakes the panel. The `enable` also
  # generates an output-config event, so kanshi re-matches and restores
  # geometry/scale/mode + the color-profile hook. (Power on/off events are
  # invisible to kanshi; only enable/disable trigger it.)
  wake-displays = pkgs.writeShellScript "wake-displays" ''
    ${pkgs.sway}/bin/swaymsg "output * enable"
  '';
  sleep-displays = pkgs.writeShellScript "sleep-displays" ''
    ${pkgs.sway}/bin/swaymsg "output * disable"
  '';
in
{
  services.swayidle = {
    enable = true;
    systemdTarget = "graphical-session.target";

    timeouts = [
      # Disable displays after 5 minutes idle. Using disable (not power off)
      # so the wake path can do a full modeset that actually retrains the
      # link through the KVM. Lets the OLED panel enter standby for its
      # compensation cycle; lock is manual, not auto.
      {
        timeout = 300;
        command = "${sleep-displays}";
        resumeCommand = "${wake-displays}";
      }
    ];

    events = [
      # Re-enable displays on resume from suspend
      {
        event = "after-resume";
        command = "${wake-displays}";
      }
    ];
  };
}
