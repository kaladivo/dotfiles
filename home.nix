{ config, pkgs, lib, ... }:

{
  home.stateVersion = "25.11";
  programs.home-manager.enable = true;

  # Non-NixOS Linux support
  targets.genericLinux.enable = true;

  # --- Packages ---
  home.packages = with pkgs; [
    # Terminal (may need nixGL wrapper if OpenGL fails - see install.sh comments)
    ghostty

    # Remote access
    mosh

    # Development
    bun
    git
    gh
    curl
    wget
    _1password-cli
    _1password-gui

    # Fonts
    meslo-lgs-nf
  ];

  # Font discovery
  fonts.fontconfig.enable = true;

  # --- Zsh ---
  programs.zsh = {
    enable = true;

    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "yarn" ];
    };

    initContent = lib.mkMerge [
      (lib.mkBefore ''
        # Powerlevel10k instant prompt (must be near top of .zshrc)
        if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
          source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
        fi
      '')
      ''
        # Powerlevel10k theme
        source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme

        # Powerlevel10k config
        [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

        # zsh-z
        source ~/.zsh/zsh-z.plugin.zsh
        ZSHZ_CASE=smart
        zstyle ':completion:*' menu select

        # Custom functions
        [[ -f ~/.zsh/functions.zsh ]] && source ~/.zsh/functions.zsh

        # NVM
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

        # Fix Alt key for special characters (Alt+2 = @ on non-US keyboards)
        bindkey "^[2" self-insert
      ''
    ];

    shellAliases = {
      pip = "pip3";
      python = "python3";
    };
  };

  # --- Dotfiles ---
  home.file = {
    ".p10k.zsh".source = ./config/p10k.zsh;
    ".config/ghostty/config".source = ./config/ghostty-config;
    ".zsh/functions.zsh".source = ./config/functions.zsh;
    ".zsh/zsh-z.plugin.zsh".source = ./config/zsh-z.plugin.zsh;

    # Ghostty terminfo (needed for SSH from Ghostty - TERM=xterm-ghostty)
    ".terminfo" = {
      source = "${pkgs.ghostty}/share/terminfo";
      recursive = true;
    };
  };
}
