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
# Pinned to 0.11.x on purpose: nvim-treesitter's (now-frozen) master branch is
# incompatible with 0.12's treesitter core (breaks query directives → markdown
# errors). Revisit when migrating to the nvim-treesitter main branch.
NVIM_VERSION="v0.11.7"
NVIM_PREFIX="$HOME/.local/nvim"   # user-space install prefix (no sudo needed)
FONTS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"
DELTA_VERSION="0.19.2"            # git-delta: not packaged for Rocky/EPEL

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
  # Also check the install path explicitly: bootstrap runs under bash and does
  # NOT source ~/.zshenv, so ~/.local/bin may be absent from PATH on a re-run.
  # Without this check a second run would needlessly re-download starship even
  # though it's already installed.
  [[ -x "$HOME/.local/bin/starship" ]] && return
  [[ "$(uname -s)" == "Darwin" ]] && return   # provided by the Brewfile
  log "Installing starship to ~/.local/bin"
  mkdir -p "$HOME/.local/bin"
  curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"
}

# Neovim: install the official prebuilt release into ~/.local (user-space, no
# sudo). Distro packages ship 0.10 or older — too old for a modern LSP config,
# which needs 0.11+. macOS uses the up-to-date Homebrew build instead.
install_neovim() {
  if [[ "$("$NVIM_PREFIX/bin/nvim" --version 2>/dev/null | head -1)" == "NVIM ${NVIM_VERSION}" ]]; then
    return  # already at the pinned version
  fi
  local arch
  case "$(uname -m)" in
    x86_64)        arch="x86_64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) log "Unknown arch $(uname -m); skipping Neovim install"; return ;;
  esac
  local tarball="nvim-linux-${arch}.tar.gz"
  log "Installing Neovim ${NVIM_VERSION} (${arch}) to ${NVIM_PREFIX}"
  local tmp; tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/$tarball" \
    "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/${tarball}"
  rm -rf "$NVIM_PREFIX"; mkdir -p "$NVIM_PREFIX"
  tar -xzf "$tmp/$tarball" -C "$NVIM_PREFIX" --strip-components=1
  rm -rf "$tmp"
  mkdir -p "$HOME/.local/bin"
  ln -sf "$NVIM_PREFIX/bin/nvim" "$HOME/.local/bin/nvim"
}

# mise: polyglot runtime version manager (node, python, terraform, …). Installed
# user-space to ~/.local/bin; macOS gets it from the Brewfile instead.
install_mise() {
  command -v mise >/dev/null 2>&1 && return
  [[ -x "$HOME/.local/bin/mise" ]] && return
  [[ "$(uname -s)" == "Darwin" ]] && return   # provided by the Brewfile
  log "Installing mise to ~/.local/bin"
  curl -fsSL https://mise.run | sh
}

# Nerd Font for terminal glyphs. macOS installs it via the Brewfile cask; on WSL
# the terminal (and its fonts) live on Windows; so this applies only to a Linux
# desktop. User-space install into XDG fonts dir.
install_fonts() {
  command -v fc-cache >/dev/null 2>&1 || { log "fontconfig missing; skipping font install"; return; }
  fc-list 2>/dev/null | grep -qi 'opendyslexic' && return   # already installed
  log "Installing OpenDyslexic Nerd Font to $FONTS_DIR"
  local tmp; tmp="$(mktemp -d)"
  if curl -fsSL -o "$tmp/OpenDyslexic.zip" \
      "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/OpenDyslexic.zip"; then
    mkdir -p "$FONTS_DIR/OpenDyslexic"
    unzip -oq "$tmp/OpenDyslexic.zip" -d "$FONTS_DIR/OpenDyslexic"
    fc-cache -f "$FONTS_DIR" >/dev/null 2>&1
  else
    log "Font download failed; skipping"
  fi
  rm -rf "$tmp"
}

# git-delta: syntax-highlighting pager for git diffs. Debian/Ubuntu install it
# via apt and macOS via the Brewfile; it isn't packaged for Rocky/EPEL, so there
# we drop a pinned prebuilt binary into ~/.local/bin.
install_delta() {
  command -v delta >/dev/null 2>&1 && return
  [[ -x "$HOME/.local/bin/delta" ]] && return
  [[ "$(uname -s)" == "Darwin" ]] && return   # Brewfile provides it
  local arch
  case "$(uname -m)" in
    x86_64)        arch="x86_64-unknown-linux-gnu" ;;
    aarch64|arm64) arch="aarch64-unknown-linux-gnu" ;;
    *) log "Unknown arch $(uname -m); skipping delta"; return ;;
  esac
  local pkg="delta-${DELTA_VERSION}-${arch}"
  log "Installing git-delta ${DELTA_VERSION} to ~/.local/bin"
  local tmp; tmp="$(mktemp -d)"
  if curl -fsSL -o "$tmp/delta.tar.gz" \
      "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/${pkg}.tar.gz"; then
    tar -xzf "$tmp/delta.tar.gz" -C "$tmp"
    mkdir -p "$HOME/.local/bin"
    install -m 0755 "$tmp/$pkg/delta" "$HOME/.local/bin/delta"
  else
    log "delta download failed; skipping"
  fi
  rm -rf "$tmp"
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
  # --restow (-R) = unstow, then stow again. Plain `stow` only ADDS links; it
  # won't remove a symlink whose source file you later deleted from a layer.
  # Restowing reconciles $HOME to the layer's *current* contents, so re-runs
  # converge on the exact desired state (idempotent toward deletions, not just
  # additions). On a first run there's nothing to unstow, so it just links.
  log "Restowing layers: $*"
  stow --restow --verbose --target "$HOME" "$@"
}

case "$(uname -s)" in
  Darwin)
    install_macos_packages
    install_antidote
    stow_layers common macos
    ;;
  Linux)
    install_linux_packages
    install_neovim
    install_starship
    install_antidote
    install_mise
    install_delta
    if is_wsl; then
      stow_layers common linux wsl
    else
      install_fonts               # Linux desktop only (WSL fonts live on Windows)
      stow_layers common linux
    fi
    ;;
  *)
    log "Unsupported OS: $(uname -s)"; exit 1
    ;;
esac

# Install language runtimes declared in the (now-stowed) mise global config.
mise_bin="$(command -v mise 2>/dev/null || true)"
[[ -z "${mise_bin:-}" && -x "$HOME/.local/bin/mise" ]] && mise_bin="$HOME/.local/bin/mise"
if [[ -n "${mise_bin:-}" ]]; then
  log "Installing language runtimes via mise (node, …)"
  "$mise_bin" install || true
fi

# Build bat's theme cache so the tracked kanagawa theme is available.
bat_bin="$(command -v bat 2>/dev/null || command -v batcat 2>/dev/null || true)"
[[ -n "${bat_bin:-}" ]] && "$bat_bin" cache --build >/dev/null 2>&1

# Nudge to make zsh the login shell (skipped if already zsh). May prompt for a
# password, and can be restricted on locked-down machines — safe to ignore.
if command -v zsh >/dev/null 2>&1 && [[ "${SHELL:-}" != *zsh ]]; then
  log "To make zsh your login shell:  chsh -s \"\$(command -v zsh)\""
fi

# Fonts are per-terminal, not per-shell: on macOS the Brewfile installs the
# Nerd Font; on a Linux desktop install one and select it in your terminal; on
# WSL install the Nerd Font on *Windows* and set it in Windows Terminal.
log "Done. Open a new zsh shell to load the config."
