#!/usr/bin/env bash
# Bootstrap dotfiles on a new machine: install packages, then symlink configs.
#
#   ./bootstrap.sh
#
# Detects the OS (and, on Linux, the package manager and whether it's running
# under WSL), installs the packages listed in packages/, then stows the right
# layers into $HOME.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

# Strip comments and blank lines from a package list.
pkglist() { grep -vE '^\s*(#|$)' "$1"; }

is_wsl() { grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; }

install_linux() {
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

install_macos() {
  if ! command -v brew >/dev/null 2>&1; then
    log "Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  log "Installing packages via Homebrew bundle"
  brew bundle --file=packages/Brewfile
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
    install_macos
    stow_layers common macos
    ;;
  Linux)
    install_linux
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

log "Done. Open a new shell to load the config."
