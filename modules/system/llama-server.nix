# llama.cpp server for slime — runtime-registry-driven.
#
# What lives in nix (declarative):
#   - The llama.cpp build (Vulkan, no webui)
#   - The systemd service that reads active model from runtime state
#   - The slime-model CLI tool packaged from ./slime-model.py
#   - The llama-server user, group, firewall port, directories
#
# What lives outside nix (runtime state managed by slime-model):
#   - /var/lib/llama-server/registry.json — installed models + metadata
#   - /var/lib/llama-server/active        — name of model to load
#   - /var/lib/llama-server/models/*.gguf — the actual weights
#
# Bringup after rebuild:
#   slime-model register <file> --name <name> --ctx <N> [...]   # for existing files
#   slime-model fetch <hf-repo> --quant Q4_K_M --name <name>    # to download fresh
#   slime-model use <name>                                       # activate
#   slime-model gen-pi-config --out ~/.pi/agent/models.json      # update pi
{ config, pkgs, lib, hostname, inputs, ... }:

let
  enabled = hostname == "slime";

  # llama.cpp from pinned source with Vulkan, web UI disabled (no npm fetch).
  # Pinned via flake input — bump with `nix flake lock --update-input llama-cpp-src`.
  llama-cpp-mtp = (pkgs.llama-cpp.override {
    vulkanSupport = true;
    cudaSupport = false;
    rocmSupport = false;
  }).overrideAttrs (old: {
    src = inputs.llama-cpp-src;
    version = "9081";
    cmakeFlags = (old.cmakeFlags or []) ++ [
      "-DLLAMA_BUILD_UI=OFF"
      "-DLLAMA_USE_PREBUILT_UI=OFF"
    ];
    npmDeps = null;
    npmRoot = null;
    nativeBuildInputs = builtins.filter
      (x: let n = x.pname or x.name or ""; in
        !(lib.hasInfix "nodejs" n || lib.hasInfix "npm-config" n))
      old.nativeBuildInputs;
    preConfigure = ''
      prependToVar cmakeFlags "-DLLAMA_BUILD_COMMIT:STRING=${inputs.llama-cpp-src.shortRev or "unknown"}"
    '';
  });

  slime-model = pkgs.writers.writePython3Bin "slime-model" {
    libraries = with pkgs.python313Packages; [ huggingface-hub ];
    flakeIgnore = [ "E501" "E402" "E741" "W503" "E265" "F401" ];
  } (builtins.readFile ./slime-model.py);

in {
  config = lib.mkIf enabled {
    networking.firewall.allowedTCPPorts = [ 8000 ];

    users.users.llama-server = {
      isSystemUser = true;
      group = "llama-server";
      extraGroups = [ "video" "render" ];
      home = "/var/lib/llama-server";
      createHome = true;
      # NixOS default homeMode is 0700 — that breaks slime-model's reads of
      # registry.json and active by non-root users. Force 0755.
      homeMode = "0755";
    };
    users.groups.llama-server = {};

    environment.systemPackages = [ llama-cpp-mtp slime-model ];

    # Initial state — empty registry, no active model. slime-model populates these.
    # `z` rules enforce perms on each boot (the dir gets created 0700 by systemd's
    # StateDirectory default and never resets without `z`; without read access the
    # `slime-model status` command fails for non-root users).
    systemd.tmpfiles.rules = [
      "d /var/lib/llama-server          0755 llama-server llama-server - -"
      "d /var/lib/llama-server/models   0755 llama-server llama-server - -"
      "z /var/lib/llama-server          0755 llama-server llama-server - -"
      "z /var/lib/llama-server/models   0755 llama-server llama-server - -"
      "f /var/lib/llama-server/registry.json 0644 llama-server llama-server - {}"
    ];

    systemd.services.llama-server = {
      description = "llama.cpp server (slime model registry)";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        AMD_VULKAN_ICD = "RADV";
        LLAMA_CACHE = "/var/lib/llama-server/cache";
        HOME = "/var/lib/llama-server";
      };

      serviceConfig = {
        Type = "simple";
        User = "llama-server";
        Group = "llama-server";
        # Don't restart on clean exit (used to signal "nothing to load yet").
        # Still restart on actual failures.
        Restart = "on-failure";
        RestartSec = 5;
        WorkingDirectory = "/var/lib/llama-server";
        # StateDirectory removed — it competes with tmpfiles for perm
        # management and resets the dir to 0700 in some service-restart paths,
        # which breaks slime-model for non-root users. tmpfiles 'd' + 'z' rules
        # below own dir creation and permissions exclusively.
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictNamespaces = true;
        ReadWritePaths = [ "/var/lib/llama-server" ];
      };

      script = ''
        active_file=/var/lib/llama-server/active
        registry=/var/lib/llama-server/registry.json

        if [[ ! -s "$active_file" ]]; then
          echo "No active model set. Run: slime-model use <name>" >&2
          exit 0
        fi
        active=$(cat "$active_file" | tr -d '[:space:]')
        if [[ -z "$active" ]]; then
          echo "Active file empty. Run: slime-model use <name>" >&2
          exit 0
        fi

        if [[ ! -s "$registry" ]]; then
          echo "Registry empty: $registry. Run slime-model register/fetch first." >&2
          exit 0
        fi

        file=$(${pkgs.jq}/bin/jq -r --arg n "$active" '.[$n].file // empty' "$registry")
        ctx=$(${pkgs.jq}/bin/jq -r --arg n "$active" '.[$n].ctx // empty' "$registry")
        if [[ -z "$file" || -z "$ctx" ]]; then
          echo "Active model '$active' not found in $registry" >&2
          exit 0
        fi

        model_path="/var/lib/llama-server/models/$file"
        if [[ ! -f "$model_path" ]]; then
          echo "Model file missing: $model_path" >&2
          exit 0
        fi

        echo "Starting llama-server: active=$active file=$file ctx=$ctx"
        exec ${llama-cpp-mtp}/bin/llama-server \
          -m "$model_path" \
          -ngl 99 -c "$ctx" -fa on \
          --cache-reuse 256 -ctk q8_0 -ctv q8_0 \
          -np 1 -t 16 \
          --host 0.0.0.0 --port 8000
      '';
    };
  };
}
