# Claude Code cache-accounting capture — declarative schedule (all hosts).
#
# Claude Code deletes completed sessions on a ~29-day rolling reaper, so per-request
# token/cost accounting must be captured before it ages out. This module declares ONLY
# the SCHEDULE (systemd --user timers). The scripts themselves live at the stable path
# ~/cache-capture/bin and are installed/updated out-of-band by install-capture.sh —
# they evolve in a separate results tree, so baking them into this repo would both
# bloat it and fight the update model. `ConditionPathExists` makes the timers no-op
# cleanly on a host not yet bootstrapped (any machine until install-capture.sh is
# run there), rather than failing loudly.
#
# systemd --user timers over a cron daemon: lighter, linger is already enabled, no
# extra daemon. Runs on every host now that CC is approved for work — capturing
# thunder's own usage is the real work-billing evidence.
{ config, pkgs, lib, hostname, ... }:

let
  # User services get a minimal PATH; pin the extractor + wrapper's deps.
  # Extractor is pure Python stdlib; the shell wrappers need coreutils, flock/logger
  # (util-linux), git, awk, and hostname.
  capturePath = lib.makeBinPath [
    pkgs.bash
    pkgs.python3
    pkgs.coreutils
    pkgs.util-linux
    pkgs.git
    pkgs.gawk
    pkgs.hostname
  ];
in
{
  # The capture: one read-only, append-only run over ~/.claude/projects.
  systemd.user.services.cache-capture = {
    Unit = {
      Description = "Capture Claude Code cache accounting before the session reaper deletes it";
      Documentation = "file:%h/cache-capture/README.md";
      ConditionPathExists = "%h/cache-capture/bin/capture-cron.sh";
    };
    Service = {
      Type = "oneshot";
      Environment = [ "PATH=${capturePath}" ];
      ExecStart = "%h/cache-capture/bin/capture-cron.sh";
      SuccessExitStatus = "0 3"; # 3 = another run holds the lock; normal, not a failure
      Nice = 10;
      IOSchedulingClass = "idle";
    };
  };

  systemd.user.timers.cache-capture = {
    Unit.Description = "Run the Claude Code cache-accounting capture every 6 hours";
    Timer = {
      # Four runs a day against a ~29-day reaper window. Box-local time; the capture's
      # own row timestamps are UTC regardless.
      OnCalendar = "*-*-* 00,06,12,18:17:00";
      Persistent = true; # catch a tick missed while the machine was off
      OnBootSec = "2min"; # reboot catch-up (the crontab @reboot line, done properly)
      AccuracySec = "1min";
      RandomizedDelaySec = 60;
      Unit = "cache-capture.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # The freshness check: a stopped capture looks exactly like a working one until you
  # need it, so surface staleness from outside. Non-zero exit marks the unit failed
  # (visible in list-timers / journal) — that is the alarm.
  systemd.user.services.cache-capture-health = {
    Unit = {
      Description = "Check the Claude Code cache-accounting capture is still fresh";
      ConditionPathExists = "%h/cache-capture/bin/capture-health.sh";
    };
    Service = {
      Type = "oneshot";
      Environment = [ "PATH=${capturePath}" ];
      ExecStart = "%h/cache-capture/bin/capture-health.sh --max-age-hours 18";
    };
  };

  systemd.user.timers.cache-capture-health = {
    Unit.Description = "Daily freshness check of the cache-accounting capture";
    Timer = {
      OnCalendar = "*-*-* 09:40:00";
      Persistent = true;
      AccuracySec = "1min";
      Unit = "cache-capture-health.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
