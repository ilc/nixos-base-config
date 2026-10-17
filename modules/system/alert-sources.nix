# Prompt alerts raised by other programs. Each entry in
# /var/lib/backup-status/alert-sources is a symlink, placed by root on the
# host, to a JSON file some program keeps only while something is wrong. While
# the target exists, its "alert" field becomes alerts/<entry name>, which the
# shell prompt shows (see backup.nix); once it is gone, that alert is removed.
# The file's content is the other program's, so it is cut to one printable
# line before it reaches a prompt.
{ pkgs, ... }:

let
  statusDir = "/var/lib/backup-status";
  sourceDir = "${statusDir}/alert-sources";
  alertDir = "${statusDir}/alerts";
in
{
  systemd.tmpfiles.rules = [
    "d ${sourceDir} 0755 root root -"
    "d ${alertDir} 0755 root root -"
  ];

  systemd.services.alert-sources = {
    description = "Copy alerts from other programs' alert files into the prompt";
    serviceConfig.Type = "oneshot";
    path = [ pkgs.jq pkgs.coreutils ];
    script = ''
      for s in ${sourceDir}/*; do
        [ -L "$s" ] || continue
        name=''${s##*/}
        out=${alertDir}/$name
        if [ -f "$s" ]; then
          msg=$(jq -r '.alert // empty' "$s" 2>/dev/null | head -n 1 | tr -cd '[:print:]' | cut -c1-200)
          [ -n "$msg" ] || msg="$name: alert file present but unreadable"
          printf '%s\n' "$msg" > "$out.tmp"
          mv "$out.tmp" "$out"
        else
          rm -f "$out"
        fi
      done
    '';
  };
  systemd.timers.alert-sources = {
    wantedBy = [ "timers.target" ];
    timerConfig = { OnBootSec = "2min"; OnUnitActiveSec = "5min"; };
  };
}
