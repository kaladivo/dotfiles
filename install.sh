#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== RPi Terminal Setup ==="
echo ""

# --- 1. Install Nix ---
if ! command -v nix &>/dev/null; then
  echo ">> Installing Nix..."
  sh <(curl -L https://nixos.org/nix/install) --daemon
  echo ""
  echo "!! Nix installed. Please restart your shell (log out and back in),"
  echo "!! then re-run this script."
  exit 0
fi

# --- 2. Enable flakes ---
mkdir -p ~/.config/nix
if ! grep -q "experimental-features" ~/.config/nix/nix.conf 2>/dev/null; then
  echo ">> Enabling flakes..."
  echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
fi

# --- 3. Apply Home Manager configuration ---
echo ">> Applying Home Manager configuration..."
echo "   (this may take a while on first run - downloading packages)"
echo ""
nix run home-manager/master -- switch --flake "$SCRIPT_DIR" --impure

# --- 4. Set zsh as default shell ---
NIX_ZSH="$HOME/.nix-profile/bin/zsh"
if [ ! -x "$NIX_ZSH" ]; then
  # Home Manager might put it in a different profile path
  NIX_ZSH="$(find /nix/store -maxdepth 2 -name zsh -path '*/bin/zsh' 2>/dev/null | head -1)"
fi

if [ -n "$NIX_ZSH" ] && [ -x "$NIX_ZSH" ]; then
  if ! grep -q "$NIX_ZSH" /etc/shells 2>/dev/null; then
    echo ">> Adding nix zsh to /etc/shells (requires sudo)..."
    echo "$NIX_ZSH" | sudo tee -a /etc/shells
  fi
  if [ "$SHELL" != "$NIX_ZSH" ]; then
    echo ">> Setting zsh as default shell..."
    chsh -s "$NIX_ZSH"
  fi
else
  echo "!! Warning: Could not find nix-installed zsh."
  echo "!! After setup, run: chsh -s \$(which zsh)"
fi

# --- 5. Install NVM + Node.js 24 ---
if [ ! -d "$HOME/.nvm" ]; then
  echo ">> Installing NVM..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

echo ">> Installing Node.js 24..."
nvm install 24

# --- 6. Install global npm tools ---
echo ">> Installing Claude Code..."
npm install -g @anthropic-ai/claude-code

echo ">> Installing OpenAI Codex CLI..."
npm install -g @openai/codex

echo ""
echo "=== Setup complete! ==="
echo ""
echo "Log out and back in (or run 'exec zsh') to activate your new shell."
echo ""
echo "If Ghostty has OpenGL issues when running with a monitor, you can either:"
echo "  1. Install Ghostty via apt: https://ghostty.org/docs/install/binary"
echo "  2. Add nixGL wrapping (see: github.com/nix-community/nixGL)"
