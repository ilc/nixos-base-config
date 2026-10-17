# /scratch/work, on every host with a /scratch mount: the blank start for
# build trees. An empty subvolume, locked read-only; each user takes its own
# writable snapshot of it, kept in its own directory on the same filesystem,
# and builds its structure there. That snapshot is its separation from every
# other user. ira owns it so the snapshots' top directory is writable;
# /scratch being root's keeps the account from removing it.
{ config, lib, pkgs, ... }:

lib.mkIf (config.fileSystems ? "/scratch") {
  systemd.tmpfiles.rules = [ "v /scratch/work 0700 ira users -" ];

  # Lock it read-only once it exists. Only while it is still empty: one that
  # somehow gained content is left alone, for a person to look at, rather than
  # locked with the content inside.
  systemd.services.scratch-work-ro = {
    description = "Lock the empty /scratch/work subvolume read-only";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-tmpfiles-setup.service" ];
    requires = [ "systemd-tmpfiles-setup.service" ];
    unitConfig.RequiresMountsFor = [ "/scratch" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [ pkgs.btrfs-progs pkgs.coreutils pkgs.findutils ];
    script = ''
      b=/scratch/work
      [ "$(stat -c %i "$b")" = 256 ] || { echo "$b is not a subvolume root"; exit 1; }
      if [ "$(btrfs property get "$b" ro)" = "ro=true" ]; then exit 0; fi
      if [ -n "$(find "$b" -mindepth 1 -print -quit)" ]; then
        echo "$b is not empty; leaving it writable"; exit 1
      fi
      btrfs property set "$b" ro true
    '';
  };
}
