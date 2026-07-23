# pi agent harness (earendil-works/pi) + sandboxed pi-yolo wrapper.
# Available on all hosts. Model server lives on slime; thunder/bear are clients.
{ config, pkgs, lib, hostname, ... }:

let
  # Sandboxed agent runner. Mounts only $PWD rw, fresh tmpfs HOME, ro-bind
  # system dirs. Network open (LLM APIs); filesystem-only protection.
  #
  # DBus access is filtered through xdg-dbus-proxy to the xdg-desktop-portal
  # namespace only — enough for clipboard (Clipboard interface lives on
  # org.freedesktop.portal.Desktop), nothing else. Blocks direct access to
  # secrets service, systemd user bus, notifications daemon, and any other
  # session-bus attack surface a compromised agent could pivot through.
  mkYolo = { name, agentPkg, agentBin, preHook ? "", extraBwrapArgs ? "" }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = with pkgs; [ bubblewrap xdg-dbus-proxy agentPkg ];
      text = ''
        work="$(pwd)"
        # Persistent sandbox state lives inside $work so it travels with the
        # project. .${name}-home is bind-mounted as the sandbox HOME at a
        # path (/sandbox) that doesn't collide with the user's real HOME —
        # this matters when $work is under $HOME, which would otherwise be
        # shadowed by binding over /home/ira.
        sandbox_state="$work/.${name}-home"
        mkdir -p "$sandbox_state"
        ${preHook}

        # Filtered dbus proxy: portal namespace only. Socket is created in a
        # per-invocation tmpdir and bound into the sandbox at a fixed path.
        proxy_dir=$(mktemp -d -t ${name}-dbus.XXXXXX)
        proxy_pid=""
        cleanup() {
          [ -n "$proxy_pid" ] && kill "$proxy_pid" 2>/dev/null || true
          rm -rf "$proxy_dir"
        }
        trap cleanup EXIT INT TERM

        if [ -n "''${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
          ${pkgs.xdg-dbus-proxy}/bin/xdg-dbus-proxy \
            "$DBUS_SESSION_BUS_ADDRESS" "$proxy_dir/bus" \
            --filter \
            --talk=org.freedesktop.portal.Desktop &
          proxy_pid=$!
          for _ in $(seq 1 50); do
            [ -S "$proxy_dir/bus" ] && break
            sleep 0.1
          done
        fi

        dbus_bind=()
        dbus_env=()
        if [ -S "$proxy_dir/bus" ]; then
          dbus_bind=(--ro-bind "$proxy_dir/bus" /run/dbus-proxy)
          dbus_env=(--setenv DBUS_SESSION_BUS_ADDRESS unix:path=/run/dbus-proxy)
        fi

        ${pkgs.bubblewrap}/bin/bwrap \
          --bind "$work" "$work" \
          --chdir "$work" \
          --ro-bind /nix /nix \
          --ro-bind /etc /etc \
          --ro-bind /usr /usr \
          --ro-bind /bin /bin \
          --ro-bind /run/current-system /run/current-system \
          --ro-bind /run/wrappers /run/wrappers \
          --dev /dev --proc /proc --tmpfs /tmp \
          --bind "$sandbox_state" /sandbox \
          "''${dbus_bind[@]}" \
          --setenv HOME /sandbox \
          --setenv PATH "$PATH" \
          --setenv TERM "''${TERM:-xterm-256color}" \
          "''${dbus_env[@]}" \
          ${extraBwrapArgs} \
          --share-net \
          --die-with-parent \
          --new-session \
          ${agentPkg}/bin/${agentBin} "$@"
      '';
    };

  pi-yolo = mkYolo {
    name = "pi-yolo";
    agentPkg = pkgs.pi-coding-agent;
    agentBin = "pi";
    # Share the user's ~/.pi (models config, auth) into the sandbox.
    # mkdir first so the bind source always exists.
    preHook = ''mkdir -p "$HOME/.pi"'';
    extraBwrapArgs = ''--bind "$HOME/.pi" /sandbox/.pi'';
  };

  oc-yolo = mkYolo {
    name = "oc-yolo";
    agentPkg = pkgs.opencode;
    agentBin = "opencode";
    # Bind opencode's config/state/cache dirs at their REAL paths inside
    # the sandbox (not /sandbox/... like pi does). Opencode resolves these
    # via getpwuid, not $HOME, so /home/ira/.config/opencode is what it
    # actually opens — putting binds under /sandbox is invisible to it.
    #   ~/.config/opencode      — opencode.json (providers, models)
    #   ~/.local/share/opencode — sqlite db, session logs, auth
    #   ~/.cache/opencode       — cached provider metadata (models.json)
    # bwrap creates the parent directory tree for these binds, so
    # /home/ira/ doesn't need to exist in the sandbox otherwise.
    preHook = ''mkdir -p "$HOME/.config/opencode" "$HOME/.local/share/opencode" "$HOME/.cache/opencode"'';
    extraBwrapArgs = ''--bind "$HOME/.config/opencode" "$HOME/.config/opencode" --bind "$HOME/.local/share/opencode" "$HOME/.local/share/opencode" --bind "$HOME/.cache/opencode" "$HOME/.cache/opencode"'';
  };

  # Benchmark sweep — runs on slime against locally installed models.
  llama-bench-sweep = pkgs.writeShellApplication {
    name = "llama-bench-sweep";
    runtimeInputs = [ ];
    text = ''
      set -u
      MODELS_DIR="''${MODELS_DIR:-/var/lib/llama-server/models}"
      LLAMA_BENCH="''${LLAMA_BENCH:-llama-bench}"
      OUT="''${OUT:-bench-results-$(date +%Y%m%d-%H%M%S).md}"

      if [[ ! -d "$MODELS_DIR" ]]; then
        echo "MODELS_DIR=$MODELS_DIR does not exist" >&2
        exit 1
      fi

      export AMD_VULKAN_ICD="''${AMD_VULKAN_ICD:-RADV}"

      {
        echo "# llama-bench sweep — $(date -Iseconds)"
        echo
        echo "Host: $(hostname)  |  AMD_VULKAN_ICD=$AMD_VULKAN_ICD"
        echo
      } > "$OUT"

      shopt -s nullglob
      for model in "$MODELS_DIR"/qwen3.6-35b-a3b-mtp-*.gguf "$MODELS_DIR"/qwen3.6-27b-mtp-*.gguf; do
        [[ -f "$model" ]] || continue
        name="$(basename "$model")"
        echo "=== $name ===" | tee -a "$OUT"
        for ctx in 512 4096 16384; do
          echo "## $name @ ctx=$ctx" | tee -a "$OUT"
          "$LLAMA_BENCH" -m "$model" -p "$ctx" -n 128 -ngl 99 -t 16 -fa 1 --output md \
            2>/dev/null | tee -a "$OUT" || echo "  (failed)" | tee -a "$OUT"
          echo | tee -a "$OUT"
        done
      done

      echo "Wrote $OUT"
    '';
  };

in {
  home.packages = with pkgs; [
    pi-coding-agent
    pi-yolo
    opencode
    oc-yolo
  ] ++ lib.optionals (hostname == "slime") [
    llama-bench-sweep
  ];

  # Disable pi's startup network ops to pi.dev (install/update telemetry,
  # version check). Nix manages pi's version; pi.dev pings serve no purpose
  # in this setup. See pi docs: telemetry + version check.
  home.sessionVariables.PI_OFFLINE = "1";

  # Pi config template — static snapshot of slime's model lineup.
  # On slime: `slime-model gen-pi-config --out ~/.pi/agent/models.json` is
  # the live source of truth. On thunder/bear: cp the template into place.
  # Keep this in sync with slime's registry when you change the lineup.
  # Two providers, same backend, different reasoning conventions:
  #   slime         → qwen-chat-template (qwen/gemma; enable_thinking via chat_template_kwargs)
  #   slime-openai  → OpenAI reasoning_effort (gpt-oss harmony; top-level reasoning_effort field)
  # Pi 0.79.1 has no "harmony" thinkingFormat literal — gpt-oss is wired via the default
  # OpenAI-style branch (no thinkingFormat + supportsReasoningEffort = true). llama-server's
  # default --jinja + --reasoning-format auto handles harmony template + analysis-channel
  # extraction into message.reasoning_content automatically.
  home.file.".pi/agent/models.json.template".text = builtins.toJSON {
    providers = {
      slime = {
        baseUrl = "http://slime:8000/v1";
        api = "openai-completions";
        apiKey = "unused";
        compat = {
          supportsDeveloperRole = false;
          thinkingFormat = "qwen-chat-template";
        };
        models = [
          { id = "qwen";                name = "Qwen3.6 35B-A3B-MTP (MoE, fast daily)";       contextWindow = 262144; maxTokens = 16384; reasoning = true; }
          { id = "qwen-dense";          name = "Qwen3.6 27B-MTP (dense, sharper, ~35 t/s)";   contextWindow = 262144; maxTokens = 16384; reasoning = true; }
          { id = "qwen-large";          name = "Qwen3-Next 80B-A3B Instruct (older but larger)"; contextWindow = 262144; maxTokens = 16384; }
          { id = "gemma";               name = "Gemma 4 26B-A4B-it (MoE, alt fast)";     contextWindow = 262144; maxTokens = 16384; reasoning = true; }
          { id = "gemma-dense";         name = "Gemma 4 31B-it (dense, slow alt)";       contextWindow = 262144; maxTokens = 16384; reasoning = true; }
        ];
      };
      slime-openai = {
        baseUrl = "http://slime:8000/v1";
        api = "openai-completions";
        apiKey = "unused";
        compat = {
          supportsDeveloperRole = false;
          supportsReasoningEffort = true;
        };
        models = [
          { id = "gpt-oss";             name = "GPT-OSS 120B (OpenAI MoE, MXFP4 native)"; contextWindow = 131072; maxTokens = 16384; reasoning = true; }
        ];
      };
    };
  };

  # opencode config template — mirror of the pi template pattern.
  # On slime: `slime-model gen-oc-config --out ~/.config/opencode/opencode.json`
  # is the live source of truth. On thunder/bear: cp the template into place.
  # Keep this in sync with slime's registry when you change the lineup.
  home.file.".config/opencode/opencode.json.template".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    # Disable opencode's built-in cloud catalog — accidents would send
    # prompts off-box. Only slime providers remain.
    disabled_providers = [ "opencode" ];
    provider = {
      slime = {
        npm = "@ai-sdk/openai-compatible";
        name = "slime";
        options = {
          baseURL = "http://slime:8000/v1";
          apiKey = "unused";
        };
        models = {
          qwen           = { name = "Qwen3.6 35B-A3B-MTP (MoE, fast daily)";     limit = { context = 262144; output = 16384; }; };
          qwen-mxfp4     = { name = "Qwen3.6 35B-A3B MXFP4 (fastest MoE)";       limit = { context = 262144; output = 16384; }; };
          qwen-dense     = { name = "Qwen3.6 27B-MTP (dense, sharper)";          limit = { context = 262144; output = 16384; }; };
          qwen-dense-ud  = { name = "Qwen3.6 27B UD-Q4_K_XL (better MTP heads)"; limit = { context = 262144; output = 16384; }; };
          qwen-large     = { name = "Qwen3-Next 80B-A3B Instruct";               limit = { context = 262144; output = 16384; }; };
          qwen-coder-next = { name = "Qwen3-Coder-Next";                          limit = { context = 262144; output = 16384; }; };
          gemma          = { name = "Gemma 4 26B-A4B-it (MoE)";                  limit = { context = 262144; output = 16384; }; };
          gemma-mxfp4    = { name = "Gemma 4 26B-A4B MXFP4 + MTP drafter";       limit = { context = 262144; output = 16384; }; };
          gemma-dense    = { name = "Gemma 4 31B-it (dense) + MTP drafter";      limit = { context = 262144; output = 16384; }; };
          laguna-mxfp4   = { name = "Laguna-S-2.1 MXFP4 (118B MoE)";             limit = { context = 262144; output = 16384; }; };
        };
      };
      slime-openai = {
        npm = "@ai-sdk/openai-compatible";
        name = "slime (gpt-oss harmony)";
        options = {
          baseURL = "http://slime:8000/v1";
          apiKey = "unused";
        };
        models = {
          gpt-oss = { name = "GPT-OSS 120B (OpenAI MoE, MXFP4)"; limit = { context = 131072; output = 16384; }; };
        };
      };
    };
  };
}
