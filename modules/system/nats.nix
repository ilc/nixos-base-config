# NATS server with JetStream (hosts in natsHosts): slime is the leaf hub,
# kraken dials it as a leaf over the home LAN.
#
# This module is the server only. Accounts, users and permissions come from
# whatever uses the bus, via files this repo never sees:
#
#   /etc/nats/nats.conf                    this module's config (store symlink)
#   /etc/nats/local/accounts.d/<owner>.conf  one per owner in accountOwners:
#                                     account entries (`name { ... }`, no
#                                     `accounts {}` wrapper), all included
#                                     inside the one accounts {} block
#   /etc/nats/local/leaf-remotes.conf      spokes: `remotes: [ ... ]`, included in
#                                     leafnodes {} (one remote per account
#                                     that crosses; the hub's URL and
#                                     /etc/nats/hub-leaf.crt as its ca_file)
#
# Local files are root:nats 0640, created empty if missing and then owned by
# their installer; this module never rewrites them. After changing one:
# `systemctl reload nats`. A new owner is one line in accountOwners.
#
# accounts.d/placeholder.conf is the module's own: an account whose only
# user's seed was thrown away at generation. It keeps the server closed while
# every owner's file is empty; with no accounts at all, nats-server accepts
# anonymous clients and leaf connections.
#
# Two pitfalls this layout avoids: a second top-level `accounts {}` block
# silently replaces the first (no error), and includes resolve relative to the
# including file, so absolute include paths don't work.
#
# Ports: clients on 127.0.0.1:4222 only. The hub's leaf port (7422, TLS with a
# self-signed certificate, remade when its names change) is open on the LAN
# and tailnet interfaces only; spokes listen on nothing. Spokes pin that certificate (copy /var/lib/nats/tls/leaf.crt from the
# hub into hosts/<spoke>/nats-hub-leaf.crt).
{ config, lib, pkgs, hostname, isNats, ... }:

let
  # Spokes dial the LAN address at home and the tailnet address away; the
  # certificate covers both, and the leaf port is open on both interfaces.
  hub = {
    host = "slime";
    lanAddress = "192.168.14.27";
    tailnetAddress = "100.68.59.89";
    interfaces = [ "enp191s0" "tailscale0" ];
    names = [ "slime" "slime.wakeful.net" ];
  };
  hubSans = lib.concatStringsSep "," (
    map (n: "DNS:${n}") hub.names
    ++ map (a: "IP:${a}") [ hub.lanAddress hub.tailnetAddress ]);
  isHub = hostname == hub.host;

  leafPort = 7422;
  dataDir = "/var/lib/nats";
  tlsDir = "${dataDir}/tls";

  # Who installs accounts; each gets accounts.d/<owner>.conf.
  accountOwners = [ "agents" ];

  # JetStream ceiling per host; accounts' own limits fit under it.
  maxFileStore = { slime = "12G"; kraken = "10G"; }.${hostname};

  hubCert = ../../hosts/${hostname}/nats-hub-leaf.crt;

  leafConfig =
    if isHub then ''
      leafnodes {
        listen: "0.0.0.0:${toString leafPort}"
        tls {
          cert_file: "${tlsDir}/leaf.crt"
          key_file: "${tlsDir}/leaf.key"
        }
      }
    '' else ''
      leafnodes {
        include "local/leaf-remotes.conf"
      }
    '';

  confFile = pkgs.writeText "nats.conf" ''
    server_name: ${hostname}
    listen: "127.0.0.1:4222"
    max_payload: 1048576
    # A connection on an address that vanished (a laptop switching from wifi
    # to wired) is only noticed when pings go unanswered; 20s x 2 bounds that
    # to about a minute instead of the default ~6.
    ping_interval: "20s"
    ping_max: 2

    jetstream {
      store_dir: "${dataDir}/jetstream"
      domain: ${hostname}
      sync_interval: always
      max_file_store: ${maxFileStore}
      max_memory_store: 0
    }

    ${leafConfig}
    accounts {
      include "local/accounts.d/placeholder.conf"
    ${lib.concatMapStrings (o: "  include \"local/accounts.d/${o}.conf\"\n") accountOwners}}
  '';

  # Create missing local files (never replace an installed one).
  localDefaults = pkgs.writeShellScript "nats-local-defaults" ''
    set -euo pipefail
    d=/etc/nats/local
    install -d -m 0750 -o root -g nats "$d" "$d/accounts.d"
    if [ ! -e "$d/accounts.d/placeholder.conf" ]; then
      pub=$(${pkgs.natscli}/bin/nats auth nkey gen user --public 2>/dev/null \
        | grep -oE '^U[A-Z2-7]{55}$')
      [ -n "$pub" ]
      printf 'placeholder {\n  users: [ { nkey: %s } ]\n}\n' "$pub" \
        | install -m 0640 -o root -g nats /dev/stdin "$d/accounts.d/placeholder.conf"
    fi
    for o in ${lib.escapeShellArgs accountOwners}; do
      [ -e "$d/accounts.d/$o.conf" ] || install -m 0640 -o root -g nats /dev/null "$d/accounts.d/$o.conf"
    done
    ${lib.optionalString (!isHub) ''
      [ -e "$d/leaf-remotes.conf" ] || install -m 0640 -o root -g nats /dev/null "$d/leaf-remotes.conf"
    ''}
  '';

  leafTls = pkgs.writeShellScript "nats-leaf-tls" ''
    set -euo pipefail
    # Made once, and again only when the names it must cover change.
    if [ -e ${tlsDir}/leaf.crt ] && [ "$(cat ${tlsDir}/leaf.sans 2>/dev/null)" = "${hubSans}" ]; then
      exit 0
    fi
    install -d -m 0700 -o nats -g nats ${tlsDir}
    ${pkgs.openssl}/bin/openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 \
      -nodes -days 3650 -subj "/CN=${hub.host}" \
      -addext "subjectAltName=${hubSans}" \
      -keyout ${tlsDir}/leaf.key -out ${tlsDir}/leaf.crt 2>/dev/null
    chown nats:nats ${tlsDir}/leaf.key ${tlsDir}/leaf.crt
    chmod 0600 ${tlsDir}/leaf.key
    chmod 0644 ${tlsDir}/leaf.crt
    echo "${hubSans}" > ${tlsDir}/leaf.sans
  '';
in
{
  config = lib.mkIf isNats {
    users.users.nats = {
      isSystemUser = true;
      group = "nats";
      home = dataDir;
    };
    users.groups.nats = { };

    environment.etc = {
      "nats/nats.conf".source = confFile;
    } // lib.optionalAttrs (!isHub) {
      "nats/hub-leaf.crt".source = hubCert;
    };

    environment.systemPackages = [ pkgs.nats-server pkgs.natscli ];

    networking.firewall.interfaces = lib.mkIf isHub (lib.genAttrs hub.interfaces
      (_: { allowedTCPPorts = [ leafPort ]; }));

    # Spokes: drop the leaf connection whenever an interface comes up or goes
    # down, so nats redials at once over whatever link is current instead of
    # waiting for pings on a socket bound to an address that no longer exists.
    networking.networkmanager.dispatcherScripts = lib.mkIf (!isHub) [{
      type = "basic";
      source = pkgs.writeText "nats-leaf-reset" ''
        case "$2" in up|down) ;; *) exit 0 ;; esac
        ${pkgs.iproute2}/bin/ss -K state established '( dport = :${toString leafPort} )' >/dev/null 2>&1 || true
      '';
    }];

    systemd.services.nats = {
      description = "NATS server (JetStream)";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      restartTriggers = [ confFile ];
      serviceConfig = {
        User = "nats";
        Group = "nats";
        StateDirectory = "nats";
        StateDirectoryMode = "0700";
        ExecStartPre = [ "+${localDefaults}" ] ++ lib.optional isHub "+${leafTls}";
        ExecStart = "${pkgs.nats-server}/bin/nats-server -c /etc/nats/nats.conf";
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
        Restart = "on-failure";
        RestartSec = 2;
        LimitNOFILE = 65536;

        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        ProtectClock = true;
        ProtectHostname = true;
        ProtectProc = "invisible";
        # AF_NETLINK: listing interface addresses for the leaf advertisement.
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" "AF_NETLINK" ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        CapabilityBoundingSet = "";
        SystemCallArchitectures = "native";
        SystemCallFilter = [ "@system-service" "~@privileged" ];
        UMask = "0077";
      };
    };
  };
}
