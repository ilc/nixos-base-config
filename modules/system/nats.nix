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
# self-signed certificate made on first start) is open on the LAN interface
# only. Spokes pin that certificate (copy /var/lib/nats/tls/leaf.crt from the
# hub into hosts/<spoke>/nats-hub-leaf.crt).
{ config, lib, pkgs, hostname, isNats, ... }:

let
  hub = {
    host = "slime";
    address = "192.168.14.27";
    lanInterface = "enp191s0";
    names = [ "slime" "slime.wakeful.net" ];
  };
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
    [ -e ${tlsDir}/leaf.crt ] && exit 0
    install -d -m 0700 -o nats -g nats ${tlsDir}
    ${pkgs.openssl}/bin/openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 \
      -nodes -days 3650 -subj "/CN=${hub.host}" \
      -addext "subjectAltName=${lib.concatMapStringsSep "," (n: "DNS:${n}") hub.names},IP:${hub.address}" \
      -keyout ${tlsDir}/leaf.key -out ${tlsDir}/leaf.crt 2>/dev/null
    chown nats:nats ${tlsDir}/leaf.key ${tlsDir}/leaf.crt
    chmod 0600 ${tlsDir}/leaf.key
    chmod 0644 ${tlsDir}/leaf.crt
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

    networking.firewall.interfaces = lib.mkIf isHub {
      ${hub.lanInterface}.allowedTCPPorts = [ leafPort ];
    };

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
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
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
