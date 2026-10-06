# Local btrfs snapshots of /home (hosts in snapshotHosts).
#
# Layout (top-level btrfs volume, mounted at /.btrfs-top):
#   @home                 /home                snapshotted
#   @snapshots/home       btrbk snapshots of @home
#   @scratch              /scratch             never snapshotted (own subvolume)
#
# Schedule: btrbk snapshots @home hourly, keeping 24 hourly + 7 daily; the daily
# is the first snapshot after 07:00. Snapshots are read-only; restore a file by
# copying it out of /.btrfs-top/@snapshots/home/@home.YYYYMMDDThhmm/.
#
# Alerts: a failed snapshot run drops a line in /var/lib/backup-status/alerts,
# which the shell prompt shows (no desktop notifier; the bar is often hidden).
{ config, lib, pkgs, isSnapshot, ... }:

let
  top = "/.btrfs-top";
  statusDir = "/var/lib/backup-status";
  alertDir = "${statusDir}/alerts";
in
{
  config = lib.mkIf isSnapshot {
    # Top-level volume, for btrbk. The @snapshots subvolume and its home/
    # directory must exist (created once by hand) before the first run.
    fileSystems.${top} = {
      device = config.fileSystems."/".device;
      fsType = "btrfs";
      options = [ "subvolid=5" "noatime" "nofail" ];
    };

    services.btrbk.instances.btrbk = {
      onCalendar = "hourly";
      settings = {
        timestamp_format = "long";
        snapshot_preserve_min = "latest";
        snapshot_preserve = "24h 7d";
        preserve_hour_of_day = "7";
        snapshot_create = "always";
        volume.${top} = {
          subvolume = {
            "@home".snapshot_dir = "@snapshots/home";
          };
        };
      };
    };

    # A broken snapshot timer must not stay silent.
    systemd.services.btrbk-btrbk.onFailure = [ "backup-alert@%n.service" ];

    systemd.services."backup-alert@" = {
      description = "Record a backup failure for the shell prompt (%i)";
      serviceConfig.Type = "oneshot";
      scriptArgs = "%i";
      script = ''
        mkdir -p ${alertDir}
        unit=''${1%.service}
        echo "$unit failed $(date '+%a %d %b %H:%M')" > ${alertDir}/$unit
      '';
    };

    systemd.tmpfiles.rules = [
      "d ${statusDir} 0755 root root -"
      "d ${alertDir} 0755 root root -"
    ];
  };
}
