# Editor configuration (neovim, emacs, zed, JetBrains)
{ config, pkgs, lib, ... }:

{
  # Neovim
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    # No Python/Ruby remote plugins in use (config is treesitter only) — take
    # the new home-manager default and drop both providers from the closure.
    withPython3 = false;
    withRuby = false;
    plugins = with pkgs.vimPlugins; [
      nvim-treesitter
      nvim-treesitter.withAllGrammars
    ];
  };

  # Emacs - symlink existing config
  home.file.".emacs.d" = {
    source = ../../dotfiles/emacs.d;
    recursive = true;
  };

  # Editor packages
  home.packages = with pkgs; [
    # Emacs
    emacs

    # Zed
    zed-editor

    # JetBrains (daily/weekly use)
    jetbrains.pycharm
    jetbrains.clion

    # LSP servers and tools
    pyright
    ccls
    gopls
    go-tools

    # Debuggers
    gdb
    delve
  ];
}
