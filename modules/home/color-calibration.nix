# Per-monitor color calibration (ICC VCGT loading)
# Maps monitor serial → ICC file → dispwin display index, loads VCGT via
# Argyll's dispwin (which speaks wlroots-gamma-control on sway 1.11+).
{ config, pkgs, lib, ... }:

{
  # Deploy ICC profiles to ~/.config/color-profiles/
  # Files are named: <whatever>-<serial>.icc — the script matches by serial.
  xdg.configFile."color-profiles" = {
    source = ./color-profiles;
    recursive = true;
  };

  home.file.".local/bin/load-color-profiles" = {
    executable = true;
    text = ''
      #!${pkgs.bash}/bin/bash
      # Load per-output ICC VCGT calibration based on monitor serial.
      # Idempotent: re-running just re-applies the same VCGT.
      set -u

      PROFILE_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/color-profiles"
      DISPWIN="${pkgs.argyllcms}/bin/dispwin"
      JQ="${pkgs.jq}/bin/jq"
      SWAYMSG="${pkgs.sway}/bin/swaymsg"

      [ -d "$PROFILE_DIR" ] || { echo "No profile dir: $PROFILE_DIR"; exit 0; }

      # Build output-name → dispwin-display-index map from `dispwin -?` help.
      # Lines look like: "    1 = 'Monitor 1, Output DP-1 at ...'"
      declare -A out2dn
      while IFS= read -r line; do
        num=$(echo "$line" | sed -nE "s/^[[:space:]]*([0-9]+) = .*/\1/p")
        output=$(echo "$line" | sed -nE "s/.*Output ([^ ,]+).*/\1/p")
        [ -n "$num" ] && [ -n "$output" ] && out2dn["$output"]="$num"
      done < <("$DISPWIN" -? 2>&1 | grep -E "^[[:space:]]*[0-9]+ = ")

      # For each connected sway output, look for a matching ICC by serial.
      "$SWAYMSG" -t get_outputs | "$JQ" -r '.[] | select(.serial != null) | "\(.name)|\(.serial)"' | \
      while IFS='|' read -r name serial; do
        icc=$(ls "$PROFILE_DIR"/*-"$serial".icc 2>/dev/null | head -1)
        [ -z "$icc" ] && continue
        dn="''${out2dn[$name]:-}"
        [ -z "$dn" ] && continue
        echo "Loading $(basename "$icc") onto $name (dispwin -d $dn)"
        "$DISPWIN" -d "$dn" "$icc"
      done
    '';
  };
}
