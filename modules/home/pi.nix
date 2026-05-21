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
      mkdir -p "$work/.pi-yolo-home"

      pi_config_args=()
      if [[ -d "$HOME/.pi" ]]; then
        pi_config_args+=(--ro-bind "$HOME/.pi" "$work/.pi-yolo-home/.pi")
      fi

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
        --bind "$work/.pi-yolo-home" "$HOME" \
        "''${pi_config_args[@]}" \
        --setenv HOME "$HOME" \
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

  # Pi config template — drop the slime provider into models.json by hand.
  home.file.".pi/agent/models.json.template".text = builtins.toJSON {
    providers = {
      slime = {
        baseUrl = "http://slime:8000/v1";
        api = "openai-completions";
        apiKey = "unused";
        compat = { supportsDeveloperRole = false; };
        models = [
          {
            id = "qwen3.6-35b-a3b-mtp";
            name = "Qwen3.6 35B-A3B-MTP (slime)";
            contextWindow = 131072;
            maxTokens = 8192;
          }
        ];
      };
    };
  };
}
