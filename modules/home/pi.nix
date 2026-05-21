# pi agent harness (earendil-works/pi) + sandboxed pi-yolo wrapper.
# Available on all hosts. Model server lives on slime; thunder/bear are clients.
{ config, pkgs, lib, hostname, ... }:

let
  # Sandboxed pi runner. Mounts only $PWD rw, fresh tmpfs HOME, ro-bind system dirs.
  # Network open (Anthropic API + slime); filesystem-only protection.
  pi-yolo = pkgs.writeShellApplication {
    name = "pi-yolo";
    runtimeInputs = with pkgs; [ bubblewrap pi-coding-agent ];
    text = ''
      work="$(pwd)"
      # Persistent sandbox state lives inside $work so it travels with the
      # project. .pi-yolo-home is bind-mounted as the sandbox HOME at a
      # path (/sandbox) that doesn't collide with the user's real HOME —
      # this matters when $work is under $HOME, which would otherwise be
      # shadowed by binding over /home/ira.
      sandbox_state="$work/.pi-yolo-home"
      mkdir -p "$sandbox_state/.pi" "$HOME/.pi"

      exec ${pkgs.bubblewrap}/bin/bwrap \
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
        --bind "$HOME/.pi" /sandbox/.pi \
        --setenv HOME /sandbox \
        --setenv PATH "$PATH" \
        --setenv TERM "''${TERM:-xterm-256color}" \
        --share-net \
        --die-with-parent \
        --new-session \
        ${pkgs.pi-coding-agent}/bin/pi "$@"
    '';
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
          { id = "qwen";        name = "Qwen3.6 35B-A3B-MTP (MoE, fast daily)";  contextWindow = 262144; maxTokens = 16384; reasoning = true; }
          { id = "qwen-dense";  name = "Qwen3.6 27B (dense, slow but sharper)";  contextWindow = 65536;  maxTokens = 16384; reasoning = true; }
          { id = "gemma";       name = "Gemma 4 26B-A4B-it (MoE, alt fast)";     contextWindow = 131072; maxTokens = 16384; }
          { id = "gemma-dense"; name = "Gemma 4 31B-it (dense, slow alt)";       contextWindow = 65536;  maxTokens = 16384; }
        ];
      };
    };
  };
}
