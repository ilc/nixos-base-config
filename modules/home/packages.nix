# User packages (consolidated from bear and slime)
{ config, pkgs, lib, hostname, ... }:

let
  # claude-yolo: Sandboxed Claude Code with full autonomy
  claude-yolo = pkgs.writeShellScriptBin "claude-yolo" ''
    # claude-yolo: Run Claude Code in a sandboxed systemd namespace
    # - Full autonomy (no permission prompts)
    # - Kernel-level isolation (systemd namespace)
    # - SSH via agent only (keys not exposed)
    # - Nix-shell works for packages

    set -euo pipefail

    PROJECT_DIR="''${1:-$(pwd)}"
    UID_NUM=$(id -u)

    # Resolve actual ssh-agent socket location
    SSH_SOCK="''${SSH_AUTH_SOCK:-/run/user/$UID_NUM/ssh-agent.socket}"

    # Verify project directory exists
    if [[ ! -d "$PROJECT_DIR" ]]; then
        echo "Error: Project directory does not exist: $PROJECT_DIR" >&2
        exit 1
    fi

    # Resolve to absolute path
    PROJECT_DIR="$(${pkgs.coreutils}/bin/realpath "$PROJECT_DIR")"

    # Ensure claude config files exist (for bind mount)
    [[ -f "$HOME/.claude.json" ]] || touch "$HOME/.claude.json"
    [[ -d "$HOME/.claude" ]] || mkdir -p "$HOME/.claude"

    echo "Starting Claude in sandbox..."
    echo "  Project: $PROJECT_DIR"
    echo "  SSH Agent: $SSH_SOCK"
    echo ""

    exec ${pkgs.systemd}/bin/systemd-run --user --pty --same-dir \
      --unit="claude-yolo-$$" \
      --description="Claude Code (sandboxed)" \
      --property=ProtectHome=tmpfs \
      --property=BindPaths="$PROJECT_DIR" \
      --property=BindReadOnlyPaths=/nix \
      --property=BindReadOnlyPaths=/etc \
      --property=BindReadOnlyPaths=/run/current-system \
      --property=BindPaths=/tmp \
      --property=BindReadOnlyPaths="$HOME/.ssh/known_hosts" \
      --property=BindReadOnlyPaths="$HOME/.gitconfig" \
      --property=BindPaths="$HOME/.claude" \
      --property=BindPaths="$HOME/.claude.json" \
      --property=BindPaths="$HOME/.cache" \
      --property=BindPaths="$HOME/.local/share/containers" \
      --property=BindPaths="/run/user/$UID_NUM/containers" \
      --property=BindPaths="$SSH_SOCK" \
      --property=ProtectSystem=strict \
      --property=PrivateUsers=false \
      --property=Environment=SSH_AUTH_SOCK="$SSH_SOCK" \
      --property=Environment=PATH="/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin" \
      -- ${pkgs.claude-code}/bin/claude --dangerously-skip-permissions --permission-mode bypassPermissions
  '';

  # Claude tools - not for thunder
  claudePackages = lib.optionals (hostname != "thunder") [
    pkgs.claude-code
    pkgs.claude-code-acp
    pkgs.claude-monitor
    claude-yolo
  ];
in
{
  home.packages = with pkgs; claudePackages ++ [

    # Browsers
    ungoogled-chromium
    firefox-bin
    tor-browser

    # 3D Printing
    bambu-studio
    orca-slicer

    # Keyboard tools (QMK)
    qmk
    qmk_hid
    via
    vial

    # Development - Languages
    python312
    go
    rustc
    cargo
    zig
    nodejs
    gnumake
    gcc

    # Development - Python
    virtualenv
    python312Packages.pep8
    python312Packages.cffi

    # Cloud CLI
    awscli2
    google-cloud-sdk
    azure-cli

    # Infrastructure
    terraform
    terraform-ls

    # Containers
    podman
    podman-compose
    libvirt

    # Terminal tools
    tmux
    zellij
    htop
    # minicom  # broken: lrzsz fails with GCC 15
    mbuffer
    file
    jq
    lsof
    killall
    usbutils
    tree
    ncdu
    unzip
    p7zip
    iftop

    # Network
    dig
    mosh

    # Fonts
    nerd-fonts.jetbrains-mono
    font-awesome

    # GUI Apps
    keepassxc
    obs-studio
    libreoffice-fresh

    # Spellcheck
    hunspell
    hunspellDicts.en-us-large

    # Security
    yubioath-flutter

    # Screenshots/Screen recording
    linuxPackages.v4l2loopback.bin

    # Wayland utilities (additional)
    libxcrypt-legacy

    # Wine (waylandFull for Wayland support)
    wineWowPackages.waylandFull
    winetricks

    # Misc utilities
    gavin-bc
    bpftrace
    shellcheck
  ];
}
