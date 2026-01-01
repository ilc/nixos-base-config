# Shell configuration (bash, starship, atuin, zoxide, pay-respects)
{ config, pkgs, lib, ... }:

{
  # Bash
  programs.bash = {
    enable = true;
    enableCompletion = true;

    shellAliases = {
      ls = "eza";
      ll = "eza -l";
      la = "eza -la";
      lt = "eza --tree";
      cat = "bat";
      grep = "rg";
      find = "fd";
    };

    # Bash init
    initExtra = ''
      # Flatpak XDG paths
      export XDG_DATA_DIRS="$XDG_DATA_DIRS:/usr/share:/var/lib/flatpak/exports/share:$HOME/.local/share/flatpak/exports/share"

      # Add ~/bin to PATH
      export PATH="$HOME/bin:$PATH"

      # pay-respects integration (press F to pay respects)
      eval "$(pay-respects bash --alias)"
    '';
  };

  # Starship prompt - ASCII-safe symbols for easy copy-paste
  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    settings = {
      # Prompt format - 2 lines
      add_newline = false;  # No blank line between prompts
      format = lib.concatStrings [
        "$directory"
        "$git_branch"
        "$git_status"
        "$python"
        "$golang"
        "$rust"
        "$nodejs"
        "$terraform"
        "$kubernetes"
        "$nix_shell"
        "$jobs"
        "$status"
        "$cmd_duration"
        "$time"
        "$line_break"
        "$username"
        "$hostname"
        "$character"
      ];

      # Character - traditional prompt
      character = {
        success_symbol = "[\\$](bold green)";
        error_symbol = "[\\$](bold red)";
      };

      # Directory - full path
      directory = {
        truncation_length = 0;
        truncate_to_repo = false;
        style = "bold cyan";
      };

      # Git - ASCII safe
      git_branch = {
        symbol = "";
        style = "bold purple";
        format = "[$symbol$branch(:$remote_branch)]($style) ";
      };

      git_status = {
        style = "bold red";
        format = "[$all_status$ahead_behind]($style)";
        conflicted = "!";
        ahead = ">";
        behind = "<";
        diverged = "<>";
        untracked = "?";
        stashed = "*";
        modified = "~";
        staged = "+";
        renamed = "r";
        deleted = "-";
      };

      # Status - show exit code on failure
      status = {
        disabled = false;
        format = "[$status]($style) ";
        style = "bold red";
      };

      # Background jobs
      jobs = {
        symbol = "&";
        style = "bold blue";
        format = "[$symbol$number]($style) ";
      };

      # Languages - ASCII safe
      python = {
        symbol = "py:";
        style = "bold yellow";
        detect_env_vars = ["VIRTUAL_ENV"];
        detect_extensions = [];
        detect_files = ["pyproject.toml" "requirements.txt" "setup.py" "Pipfile"];
        detect_folders = [".venv" "venv"];
        format = "[$symbol$virtualenv]($style) ";
      };

      golang = {
        symbol = "go:";
        style = "bold cyan";
        format = "[$symbol$version]($style) ";
      };

      rust = {
        symbol = "rs:";
        style = "bold red";
        format = "[$symbol$version]($style) ";
      };

      nodejs = {
        symbol = "node:";
        style = "bold green";
        format = "[$symbol$version]($style) ";
      };

      # Terraform
      terraform = {
        symbol = "tf:";
        style = "bold 105";
        format = "[$symbol$workspace]($style) ";
      };

      # Kubernetes
      kubernetes = {
        disabled = false;
        symbol = "k8s:";
        style = "bold blue";
        format = "[$symbol$context(/$namespace)]($style) ";
        detect_files = ["k8s" "kubernetes" "helm"];
        detect_folders = ["k8s" "kubernetes" "helm" ".kube"];
        detect_env_vars = ["KUBECONFIG"];
      };

      # Cloud - disabled (they don't support file detection, always show when creds exist)
      # Use terraform module to see workspace instead
      aws.disabled = true;
      gcloud.disabled = true;
      azure.disabled = true;

      # Nix shell indicator
      nix_shell = {
        symbol = "nix:";
        style = "bold blue";
        format = "[$symbol$state]($style) ";
      };

      # Command duration
      cmd_duration = {
        min_time = 2000;
        style = "bold yellow";
        format = "[took $duration]($style) ";
      };

      # Time
      time = {
        disabled = false;
        format = "[$time]($style) ";
        style = "bold white";
        time_format = "%y-%m-%d %a %H:%M:%S%z";
      };

      # Username
      username = {
        show_always = true;
        format = "[$user]($style)@";
        style_user = "bold green";
      };

      # Hostname - show always
      hostname = {
        ssh_only = false;
        format = "[$hostname]($style) ";
        style = "bold green";
      };
    };
  };

  # Atuin (shell history)
  programs.atuin = {
    enable = true;
    enableBashIntegration = true;
    settings = {
      auto_sync = false;
      style = "full";
      inline_height = 0;
      enter_accept = false;
    };
  };

  # Zoxide (smart cd)
  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
  };

  # FZF (fuzzy finder)
  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
  };

  # Direnv (per-directory environments)
  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    nix-direnv.enable = true;
  };

  # Eza (modern ls)
  programs.eza = {
    enable = true;
    enableBashIntegration = true;
    icons = "auto";
    git = true;
  };

  # Bat (better cat)
  programs.bat = {
    enable = true;
    config = {
      theme = "ansi";
      style = "numbers,changes";
    };
  };

  # Shell tools packages
  home.packages = with pkgs; [
    pay-respects
    fd
    ripgrep
    dust
    btop
    delta
  ];
}
