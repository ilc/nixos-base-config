# User packages (consolidated from bear and slime)
{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    # Claude tools
    claude-code
    claude-code-acp
    claude-monitor

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
    # azure-cli  # Uncomment if needed

    # Infrastructure
    terraform

    # Containers
    podman
    podman-compose
    libvirt

    # Terminal tools
    tmux
    zellij
    # minicom  # broken: lrzsz fails with GCC 15
    mbuffer
    file
    jq
    lsof
    killall
    usbutils

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
