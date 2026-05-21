# llama.cpp server for slime — Qwen3.6-35B-A3B-MTP with Vulkan backend.
# Only active on slime. Other hosts get no-op.
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
    # Must be numeric — interpolated into LLAMA_BUILD_NUMBER (C++ int literal).
    # Bump when upstream nixpkgs goes past this.
    version = "9081";

    # Strip the embedded web UI (CMake option new in recent main).
    # Removes the npm fetch entirely — no node deps come into the build.
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

  modelPath = "/var/lib/llama-server/models/qwen3.6-35b-a3b-mtp-UD-Q4_K_M.gguf";
in {
  config = lib.mkIf enabled {
    # Open serving port to LAN. Adjust firewall as needed for your network shape.
    networking.firewall.allowedTCPPorts = [ 8000 ];

    # Dedicated service user with GPU group access (video + render for Vulkan/iGPU).
    users.users.llama-server = {
      isSystemUser = true;
      group = "llama-server";
      extraGroups = [ "video" "render" ];
      home = "/var/lib/llama-server";
      createHome = true;
    };
    users.groups.llama-server = {};

    # Expose llama-cpp + bench tools to the user too (debugging on slime)
    environment.systemPackages = [ llama-cpp-mtp ];

    systemd.services.llama-server = {
      description = "llama.cpp server (Qwen3.6-35B-A3B-MTP, Vulkan)";
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
        Restart = "on-failure";
        RestartSec = 5;
        WorkingDirectory = "/var/lib/llama-server";
        StateDirectory = "llama-server";
        StateDirectoryMode = "0755";

        # Sandboxing — restrict but allow GPU + network
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
        if [[ ! -f "${modelPath}" ]]; then
          echo "Model not found at ${modelPath}" >&2
          echo "Download with (as the llama-server user):" >&2
          echo "  sudo -u llama-server huggingface-cli download \\" >&2
          echo "    unsloth/Qwen3.6-35B-A3B-MTP-GGUF UD-Q4_K_M.gguf \\" >&2
          echo "    --local-dir /var/lib/llama-server/models" >&2
          exit 1
        fi

        # MTP speculative decoding: the model has draft-MTP heads embedded
        # (unsloth/Qwen3.6-35B-A3B-MTP-GGUF), and our pinned llama.cpp
        # build supports --spec-type draft-mtp.
        exec ${llama-cpp-mtp}/bin/llama-server \
          -m "${modelPath}" \
          -ngl 99 \
          -c 131072 \
          -fa on \
          --cache-reuse 256 \
          -ctk q8_0 -ctv q8_0 \
          -np 1 \
          -t 16 \
          --spec-type draft-mtp \
          --spec-draft-n-max 2 \
          --host 0.0.0.0 \
          --port 8000
      '';
    };
  };
}
