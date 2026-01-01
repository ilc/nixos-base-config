{
  config,
  pkgs,
  nixpkgs,
  ...
}: {
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "ira";
  home.homeDirectory = "/home/ira";
  fonts.fontconfig.enable = true;

  home.packages = [
    pkgs.claude-code
    pkgs.claude-code-acp
    pkgs.claude-monitor
    pkgs.qmk
    pkgs.bpftrace
    pkgs.ungoogled-chromium
    pkgs.bambu-studio
    pkgs.rofi
    pkgs.grim
    pkgs.zed-editor
    pkgs.pyright
    pkgs.ccls
    pkgs.eza
    pkgs.tor-browser
    pkgs.atuin
    pkgs.shellcheck
    pkgs.kanshi
    pkgs.qmk_hid
    pkgs.swaysome
    pkgs.minicom
    pkgs.usbutils
    pkgs.firefox-bin
    pkgs.yubioath-flutter
    pkgs.gavin-bc
    pkgs.libxcrypt-legacy
    pkgs.font-awesome
    pkgs.kitty
    pkgs.git
    pkgs.helix
    pkgs.shikane
#    pkgs.python312Packages.msrest
#    pkgs.azure-cli
    pkgs.gh
    pkgs.gdb
    pkgs.tmux
    pkgs.fzf
    pkgs.awscli2
    pkgs.ripgrep
    pkgs.google-cloud-sdk
    pkgs.virtualenv
    pkgs.nerd-fonts.jetbrains-mono
    pkgs.python312
    pkgs.libvirt
    pkgs.waybar
    pkgs.lsof
    pkgs.mosh
    pkgs.podman
    pkgs.podman-compose
    pkgs.keepassxc
    pkgs.gcc
    pkgs.rustc
    pkgs.zig
    pkgs.dig
    pkgs.yubioath-flutter
    pkgs.wofi
    pkgs.bemenu
    pkgs.slurp
    pkgs.jq
    pkgs.obs-studio
    pkgs.linuxPackages.v4l2loopback.bin
    pkgs.killall
    pkgs.libreoffice-fresh
    pkgs.hunspell
    pkgs.hunspellDicts.en-us-large
    pkgs.mbuffer
    pkgs.python312Packages.pep8
    pkgs.zellij
    pkgs.emacs
    pkgs.gnumake
    pkgs.python312Packages.cffi
    pkgs.rustc
    pkgs.cargo
    pkgs.terraform
    pkgs.file
    pkgs.super-productivity
    pkgs.wl-clipboard
#    pkgs.vagrant
    #    pkgs.python310Packages.
    #    pkgs.python310Packages.
    #    pkgs.vivaldi
    #    pkgs.vivaldi-ffmpeg-codecs
    #    pkgs.podman
    #    pkgs.podman-compose
    pkgs.jetbrains.pycharm-professional
    pkgs.jetbrains.clion
    pkgs.jetbrains.webstorm
    pkgs.jetbrains.idea-ultimate
    pkgs.jetbrains.goland
    pkgs.go
    pkgs.gopls
    pkgs.go-tools
    pkgs.delve
  ];

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "23.05";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  programs.neovim = {
    viAlias = true;
    vimAlias = true;
    enable = true;
    plugins = [
      pkgs.vimPlugins.nvim-treesitter
      pkgs.vimPlugins.nvim-treesitter.withAllGrammars
    ];
  };

  programs.vscode = {
    enable = true;
    extensions = with pkgs.vscode-extensions; [
      vscodevim.vim
#      ms-python.python
      ms-vscode-remote.remote-ssh
      #ms-vscode.cpptools
      #    ms-vscode-remote.vscode-remote-extensionpack
      mhutchie.git-graph
      hashicorp.terraform
      ms-vscode.makefile-tools
      #    amazonwebservices.aws-toolkit-vscode
      bbenoist.nix
      donjayamanne.githistory
      johnpapa.vscode-peacock
      oderwat.indent-rainbow
      golang.go
      #    AmazonWebServices.aws-toolkit-vscode
      #    eamodio.gitlens
    ];
  };

  #  wayland.windowManager.sway = {
  #    enable = true;
  #    config = null;
  #    config = rec {
  #      modifier = "Mod4";
  #     # Use kitty as default terminal
  #      terminal = "kitty";
  #      startup = [
  # Launch Firefox on start
  #        {command = "firefox";}
  #      ];
  #    };
  #    extraOptions = [ "--unsupported-gpu" ];
  #  };
}
