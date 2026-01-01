# Git configuration
{ config, pkgs, lib, ... }:

{
  programs.git = {
    enable = true;

    # User info left unconfigured (set per-repo or globally outside Nix)
    # userName = "Ira Cooper";
    # userEmail = "your@email.com";

    settings = {
      init.defaultBranch = "main";
      pull.rebase = false;
      push.autoSetupRemote = true;

      # Use delta for diffs
      core.pager = "delta";
      interactive.diffFilter = "delta --color-only";
      delta = {
        navigate = true;
        light = false;
        line-numbers = true;
      };

      merge.conflictstyle = "diff3";
      diff.colorMoved = "default";
    };
  };

  # GitHub CLI
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
    };
  };
}
