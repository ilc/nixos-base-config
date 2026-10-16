# Home backup (hosts in homeBackupHosts): restic to S3 from the btrbk snapshots
# that snapshots.nix takes (a homeBackupHost must also be a snapshotHost).
#
# Layout (top-level btrfs volume, mounted at /.btrfs-top):
#   @home                 /home                snapshotted, backed up to S3
#   @snapshots/home       btrbk snapshots of @home
#
# What stays out of the S3 backup is marked in place: any directory holding a
# `.nobackup` file is skipped with everything under it (Downloads,
# browser profiles, …). `find ~ -name .nobackup` lists every opted-out tree.
#
# Schedule: btrbk snapshots @home hourly, keeping 24 hourly + 7 daily. restic
# backs up one snapshot a day, read-only and frozen, mounted over /home in the
# unit's namespace so restic sees stable /home paths. Weekly forget+prune and a
# weekly partial data check follow. When each runs is per host (`targets`):
#   slime   overnight, a fresh snapshot, uncapped (nobody is on a call)
#
# Target (S3 API): slime → Backblaze B2. Safety: the key can't destroy data:
# the bucket keeps prior
# versions for 30 days, and the key is bucket-only with no bucket-settings
# rights. Secrets live in /etc/restic (root-only), never in git.
#
# Alerts: failures and staleness drop a line in /var/lib/backup-status/alerts,
# which the shell prompt shows.
{ config, lib, pkgs, hostname, isHomeBackup, ... }:

let
  top = "/.btrfs-top";
  snapHome = "${top}/@snapshots/home";
  statusDir = "/var/lib/backup-status";
  alertDir = "${statusDir}/alerts";
  snoozeDir = "${statusDir}/snooze";
  targets = {
    slime = {
      region = "us-east-005";
      endpoint = "https://s3.us-east-005.backblazeb2.com";
      s3Options = [ ];
      uploadArgs = [ ];
      snapshot = "latest";
      backupAt = "*-*-* 03:30";
      pruneAt = "Wed 04:30";
      checkAt = "Thu 04:30";
    };
  };
  target = targets.${hostname};
  s3Endpoint = target.endpoint;

  # "morning": the backup reads today's first snapshot at or after
  # 07:00 (btrbk names them @home.YYYYMMDDThhmm). No such snapshot (machine
  # off at 07:00, btrbk hiccup) → take one now and use it, so the backup always
  # reflects today. Still none → fail, which raises an alert: snapshots broke.
  # "latest" (manual push): the newest snapshot, after taking a fresh one.
  selectSnapshot = pkgs.writeShellScript "restic-select-snapshot" ''
    set -euo pipefail
    today=$(date +%Y%m%d)
    todays() { ls -1 ${snapHome} | grep -E "^@home\.$today"'T[0-9]{4}(_[0-9]+)?$' | sort || true; }
    pick=""
    if [ "''${1:-}" != latest ]; then
      pick=$(todays | grep -E 'T(0[7-9]|1[0-9]|2[0-3])[0-9]{2}(_[0-9]+)?$' | head -1 || true)
    fi
    if [ -z "$pick" ]; then
      echo "no usable snapshot from today; taking one now"
      ${pkgs.systemd}/bin/systemctl start btrbk-btrbk.service
      pick=$(todays | tail -1)
    fi
    [ -n "$pick" ] || { echo "btrbk produced no snapshot today in ${snapHome}" >&2; exit 1; }
    mkdir -p /run/restic-src
    ln -sfn ${snapHome}/$pick /run/restic-src/home
    echo "backing up snapshot $pick"
  '';

  # One exclude list for the scheduled job and manual pushes. Beyond these
  # paths, any directory holding a `.nobackup` file, a Python venv's pyvenv.cfg
  # (whatever the venv is named: env, .venv, …), or a standard CACHEDIR.TAG
  # is skipped — that's how a directory opts out without config edits.
  excludeFile = pkgs.writeText "restic-home-excludes" (lib.concatLines [
    "/home/ira/.cache"
    "/home/ira/.lima"
    "/home/ira/vagrant"
    "/home/ira/.cargo/registry"
    "/home/ira/.cargo/git"
    "/home/ira/.local/share/Trash"
    "**/.local/share/containers"
    "**/node_modules"
    "**/__pycache__"
    "**/target"
    "**/.direnv"
    # App caches kept under ~/.config (Electron and Chromium-based apps)
    "/home/ira/.config/*/Cache"
    "/home/ira/.config/*/Code Cache"
    "/home/ira/.config/*/GPUCache"
    "/home/ira/.config/*/CachedData"
    "/home/ira/.config/*/Service Worker/CacheStorage"
    "/home/ira/.config/PCSX2"
  ]);

  # Skip quietly when S3 isn't reachable (travelling, offline); curl exits 0 on
  # any HTTP answer, non-zero only when there's no network path.
  onlineCheck = pkgs.writeShellScript "backup-online-check" ''
    ${pkgs.curl}/bin/curl -s -o /dev/null --max-time 15 ${s3Endpoint}
  '';

  markOk = unit: pkgs.writeShellScript "backup-mark-ok" ''
    mkdir -p ${alertDir}
    date --iso-8601=seconds > ${statusDir}/${unit}.last-ok
    rm -f ${alertDir}/${unit}
    ${lib.optionalString (unit == "restic-backups-home") "rm -f ${alertDir}/stale"}
  '';

  # Units shared by the restic jobs: AC power only, S3 reachable, run after the
  # network is up, record success, raise an alert on failure.
  jobCommon = unit: {
    unitConfig.ConditionACPower = true;
    onFailure = [ "backup-alert@%n.service" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      ExecCondition = onlineCheck;
      ExecStartPost = markOk unit;
      Nice = 10;
      IOSchedulingClass = "idle";
    };
  };

  # Wrapper generated by services.restic (createWrapper): same repo, password,
  # S3 env and -o options as the backup unit.
  resticHome = "/run/current-system/sw/bin/restic-home";
in
{
  config = lib.mkIf isHomeBackup {
    services.restic.backups.home = {
      initialize = false;  # `restic-home init` once, by hand
      repositoryFile = "/etc/restic/repository";
      passwordFile = "/etc/restic/password";
      environmentFile = "/etc/restic/s3.env";
      inhibitsSleep = true;
      paths = [ "/home" ];
      extraOptions = [ "s3.connections=24" "s3.region=${target.region}" ] ++ target.s3Options;
      # The first seed runs uncapped via `restic-push-home`.
      extraBackupArgs = [ "--pack-size=64" "--host=${hostname}" "--tag=scheduled" "--exclude-file=${excludeFile}" "--exclude-if-present=.nobackup" "--exclude-if-present=pyvenv.cfg" "--exclude-caches" ] ++ target.uploadArgs;
      timerConfig = {
        OnCalendar = target.backupAt;
        Persistent = true;
      };
    };

    systemd.services.restic-backups-home = lib.recursiveUpdate (jobCommon "restic-backups-home") {
      requires = [ "restic-select-snapshot.service" ];
      after = [ "restic-select-snapshot.service" ];
      # Resolved at unit start, after the selector has pointed the link.
      serviceConfig.BindReadOnlyPaths = [ "/run/restic-src/home:/home" ];
    };

    systemd.services.restic-select-snapshot = {
      description = "Point the restic source at the @home snapshot to back up";
      unitConfig.ConditionACPower = true;
      onFailure = [ "backup-alert@%n.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${selectSnapshot}${lib.optionalString (target.snapshot == "latest") " latest"}";
      };
    };

    systemd.services.restic-prune-home = lib.recursiveUpdate (jobCommon "restic-prune-home") {
      description = "restic forget + prune (home)";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${resticHome} forget --host ${hostname} --keep-daily 10 --keep-weekly 8 --keep-monthly 24 --prune --max-unused 10%";
      };
    };
    systemd.timers.restic-prune-home = {
      wantedBy = [ "timers.target" ];
      timerConfig = { OnCalendar = target.pruneAt; Persistent = true; };
    };

    systemd.services.restic-check-home = lib.recursiveUpdate (jobCommon "restic-check-home") {
      description = "restic check, reading 5% of the data (home)";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${resticHome} check --read-data-subset=5%";
      };
    };
    systemd.timers.restic-check-home = {
      wantedBy = [ "timers.target" ];
      timerConfig = { OnCalendar = target.checkAt; Persistent = true; };
    };

    # Staleness: no successful backup in 4 days (a weekend plus a holiday).
    systemd.services.backup-stale-check = {
      description = "Raise a prompt alert if the home backup is stale";
      serviceConfig.Type = "oneshot";
      script = ''
        mkdir -p ${alertDir}
        today=$(date +%F)
        for w in ${snoozeDir}/*_*; do
          [ -e "$w" ] || continue
          w=''${w##*/}
          if [[ ! "$today" < "''${w%_*}" && ! "$today" > "''${w#*_}" ]]; then
            echo "snoozed ($w)"; exit 0
          fi
        done
        f=${statusDir}/restic-backups-home.last-ok
        if [ ! -e "$f" ] || [ $(( $(date +%s) - $(date -d "$(cat $f)" +%s) )) -gt 345600 ]; then
          echo "no successful backup since $(cat $f 2>/dev/null || echo never)" > ${alertDir}/stale
        fi
      '';
    };
    systemd.timers.backup-stale-check = {
      wantedBy = [ "timers.target" ];
      timerConfig = { OnCalendar = "*-*-* 14:00"; OnBootSec = "15min"; Persistent = true; };
    };

    systemd.tmpfiles.rules = [
      "d ${snoozeDir} 0755 root root -"
      "d /etc/restic 0700 root root -"
    ];

    environment.systemPackages = [
      (pkgs.writeShellApplication {
        name = "backup-snooze";
        runtimeInputs = [ pkgs.awscli2 pkgs.coreutils ];
        text = ''
          # Quiet the staleness alarms (local prompt + provider email) for a date
          # window, e.g. a holiday with the machine off. Failures still alert.
          #   backup-snooze UNTIL | FROM UNTIL      (YYYY-MM-DD, inclusive)
          #   backup-snooze --list | --cancel FROM_UNTIL
          # Each window is its own object, control/snooze/FROM_UNTIL, in the
          # backup bucket; windows outside today are ignored.
          [ "$(id -u)" = 0 ] || { echo "run with sudo" >&2; exit 1; }
          set -a
          # shellcheck source=/dev/null
          . /etc/restic/s3.env
          set +a
          repo=$(cat /etc/restic/repository)        # s3:host/bucket/prefix
          bucket=''${repo#s3:*/}; bucket=''${bucket%%/*}
          s3() { aws --region ${target.region} --endpoint-url ${target.endpoint} s3api "$@"; }
          valid() { date -d "$1" +%F >/dev/null 2>&1 && [ "$(date -d "$1" +%F)" = "$1" ]; }
          case "''${1:-}" in
            --list)
              ls -1 ${snoozeDir}
              ;;
            --cancel)
              w=''${2:?window, as shown by --list}
              s3 delete-object --bucket "$bucket" --key "control/snooze/$w" >/dev/null
              rm -f "${snoozeDir}/$w"; echo "cancelled $w"
              ;;
            "") echo "usage: backup-snooze UNTIL | FROM UNTIL | --list | --cancel FROM_UNTIL" >&2; exit 2 ;;
            *)
              if [ $# -ge 2 ]; then from=$1; until=$2; else from=$(date +%F); until=$1; fi
              if ! valid "$from" || ! valid "$until"; then echo "dates must be YYYY-MM-DD" >&2; exit 2; fi
              [[ ! "$until" < "$from" ]] || { echo "UNTIL is before FROM" >&2; exit 2; }
              w="''${from}_''${until}"
              s3 put-object --bucket "$bucket" --key "control/snooze/$w" --checksum-algorithm SHA256 >/dev/null
              touch "${snoozeDir}/$w"; echo "snoozed $w"
              ;;
          esac
        '';
      })
      (pkgs.writeShellApplication {
        name = "restic-push-home";
        runtimeInputs = [ pkgs.systemd pkgs.coreutils ];
        text = ''
          # Back up /home now: take a fresh snapshot and push it, uncapped.
          # Extra arguments go to restic (e.g. --limit-upload=1200 on a call).
          # The first run doubles as the initial seed — start that overnight.
          [ "$(id -u)" = 0 ] || { echo "run with sudo" >&2; exit 1; }
          ${selectSnapshot} latest
          systemd-run --wait --pty --unit=restic-push-home \
            -p BindReadOnlyPaths=/run/restic-src/home:/home \
            -p Nice=10 -p IOSchedulingClass=idle \
            -p CacheDirectory=restic-backups-home \
            ${resticHome} backup /home --pack-size=64 --host=${hostname} --tag=manual \
              --exclude-file=${excludeFile} --exclude-if-present=.nobackup --exclude-if-present=pyvenv.cfg --exclude-caches "$@"
          ${markOk "restic-backups-home"}
        '';
      })
    ];
  };
}
