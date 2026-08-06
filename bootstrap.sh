#!/usr/bin/env bash
# Bootstrap dotfiles on a new machine: install packages + tools, then link configs.
#
#   ./bootstrap.sh
#
# Detects the OS (and, on Linux, the package manager and whether it's running
# under WSL), installs packages from packages/, installs shell tooling
# (starship, antidote), then stows the right layers into $HOME.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES"

ANTIDOTE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/antidote"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

# Strip comments and blank lines from a package list.
pkglist() { grep -vE '^\s*(#|$)' "$1"; }

is_wsl() { grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; }

install_linux_packages() {
  if command -v apt-get >/dev/null 2>&1; then
    log "Installing packages via apt"
    sudo apt-get update
    sudo apt-get install -y $(pkglist packages/apt.txt)
  elif command -v dnf >/dev/null 2>&1; then
    log "Installing packages via dnf"
    sudo dnf install -y epel-release || true   # some packages need EPEL
    sudo dnf install -y $(pkglist packages/dnf.txt)
  else
    log "No supported package manager (apt/dnf) found; skipping package install"
  fi
}

install_macos_packages() {
  if ! command -v brew >/dev/null 2>&1; then
    log "Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  log "Installing packages via Homebrew bundle"
  brew bundle --file=packages/Brewfile
}

# starship: in the Brewfile on macOS; installed to ~/.local/bin on Linux (it
# isn't reliably packaged in apt/dnf).
install_starship() {
  command -v starship >/dev/null 2>&1 && return
  [[ "$(uname -s)" == "Darwin" ]] && return   # provided by the Brewfile
  log "Installing starship to ~/.local/bin"
  mkdir -p "$HOME/.local/bin"
  curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"
}

# antidote: cloned to XDG_DATA_HOME on every OS for a uniform path.
install_antidote() {
  [[ -d "$ANTIDOTE_DIR" ]] && return
  log "Installing antidote (zsh plugin manager)"
  git clone --depth=1 https://github.com/mattmc3/antidote.git "$ANTIDOTE_DIR"
}

stow_layers() {
  if ! command -v stow >/dev/null 2>&1; then
    log "stow not installed; skipping linking (install it and re-run)"
    return
  fi
  log "Stowing layers: $*"
  stow --verbose --target "$HOME" "$@"
}

case "$(uname -s)" in
  Darwin)
    install_macos_packages
    install_antidote
    stow_layers common macos
    ;;
  Linux)
    install_linux_packages
    install_starship
    install_antidote
    if is_wsl; then
      stow_layers common linux wsl
    else
      stow_layers common linux
    fi
    ;;
  *)
    log "Unsupported OS: $(uname -s)"; exit 1
    ;;
esac

# Nudge to make zsh the login shell (skipped if already zsh). May prompt for a
# password, and can be restricted on locked-down machines — safe to ignore.
if command -v zsh >/dev/null 2>&1 && [[ "${SHELL:-}" != *zsh ]]; then
  log "To make zsh your login shell:  chsh -s \"\$(command -v zsh)\""
fi

# Fonts are per-terminal, not per-shell: on macOS the Brewfile installs the
# Nerd Font; on a Linux desktop install one and select it in your terminal; on
# WSL install the Nerd Font on *Windows* and set it in Windows Terminal.
log "Done. Open a new zsh shell to load the config."
