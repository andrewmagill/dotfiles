#!/usr/bin/env bash
# Bootstrap dotfiles on a new machine: install packages + tools, then link configs.
#
#   ./bootstrap.sh
#
# Detects the OS (and, on Linux, the package manager and whether it's under WSL),
# installs packages from packages/, installs pinned prebuilt tools that aren't
# packaged (Neovim, Starship, mise, git-delta, AWS CLI, sqlcmd, ripsecrets,
# Claude Code) and the Sono font, then stows the right layers into $HOME.
#
# Structure note: strict mode and all side effects live in main(); the top level
# only defines constants + functions, so the script can be *sourced* (e.g. by the
# Bats tests in tests/) without doing anything.

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DOTFILES

readonly ANTIDOTE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/antidote"
readonly FONTS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"
readonly SONO_BASE="https://raw.githubusercontent.com/sursly/sono/master/fonts/ttf"
# Pinned to 0.11.x on purpose: nvim-treesitter's (now-frozen) master branch is
# incompatible with 0.12's treesitter core (breaks query directives → markdown
# errors). Revisit when migrating to the nvim-treesitter main branch.
readonly NVIM_VERSION="v0.11.7"
readonly NVIM_PREFIX="$HOME/.local/nvim"   # user-space install prefix (no sudo needed)
readonly DELTA_VERSION="0.19.2"            # git-delta: not packaged for Rocky/EPEL
readonly SQLCMD_VERSION="v1.10.0"          # go-sqlcmd: modern single-binary sqlcmd
readonly RIPSECRETS_VERSION="0.1.11"       # pre-commit secret scanner (see .githooks/)

# Temp dirs are registered here and removed by cleanup() on EXIT, so a failed
# curl/tar mid-install never leaves a stray directory behind.
TMPDIRS=()
cleanup() {
  [[ ${#TMPDIRS[@]} -gt 0 ]] && rm -rf "${TMPDIRS[@]}"
  return 0
}

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# Strip comments and blank lines from a package list.
pkglist() { grep -vE '^\s*(#|$)' "$1"; }

# True when running under WSL. Reads $WSL_VERSION_FILE (default /proc/version) so
# it's unit-testable.
is_wsl() { grep -qiE 'microsoft|wsl' "${WSL_VERSION_FILE:-/proc/version}" 2>/dev/null; }

install_linux_packages() {
  if command -v apt-get >/dev/null 2>&1; then
    log "Installing packages via apt"
    sudo apt-get update
    # shellcheck disable=SC2046  # intentional word-splitting of the package list
    sudo apt-get install -y $(pkglist packages/apt.txt)
  elif command -v dnf >/dev/null 2>&1; then
    log "Installing packages via dnf"
    sudo dnf install -y epel-release || true   # some packages need EPEL
    # shellcheck disable=SC2046  # intentional word-splitting of the package list
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
  [[ -x "$HOME/.local/bin/starship" ]] && return
  [[ "$(uname -s)" == "Darwin" ]] && return   # provided by the Brewfile
  log "Installing starship to ~/.local/bin"
  mkdir -p "$HOME/.local/bin"
  curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"
}

# Neovim: install the pinned official prebuilt release into ~/.local (user-space,
# no sudo) on BOTH Linux and macOS, so every machine runs the exact same version.
install_neovim() {
  if [[ "$("$NVIM_PREFIX/bin/nvim" --version 2>/dev/null | head -1)" == "NVIM ${NVIM_VERSION}" ]]; then
    return  # already at the pinned version
  fi
  local os arch
  case "$(uname -s)" in
    Linux)  os="linux" ;;
    Darwin) os="macos" ;;
    *) log "Unsupported OS for Neovim install"; return ;;
  esac
  case "$(uname -m)" in
    x86_64)        arch="x86_64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) log "Unknown arch $(uname -m); skipping Neovim install"; return ;;
  esac
  local tarball="nvim-${os}-${arch}.tar.gz"
  log "Installing Neovim ${NVIM_VERSION} (${os}-${arch}) to ${NVIM_PREFIX}"
  local tmp; tmp="$(mktemp -d)"; TMPDIRS+=("$tmp")
  if curl -fsSL -o "$tmp/$tarball" \
      "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/${tarball}"; then
    rm -rf "$NVIM_PREFIX"; mkdir -p "$NVIM_PREFIX"
    tar -xzf "$tmp/$tarball" -C "$NVIM_PREFIX" --strip-components=1
    if [[ "$os" == "macos" ]]; then
      # Clear the Gatekeeper quarantine flag on the freshly-downloaded binary.
      xattr -r -d com.apple.quarantine "$NVIM_PREFIX" 2>/dev/null || true
    fi
    mkdir -p "$HOME/.local/bin"
    ln -sf "$NVIM_PREFIX/bin/nvim" "$HOME/.local/bin/nvim"
  else
    log "Neovim download failed; skipping"
  fi
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

# Claude Code — native installer (self-contained binary in ~/.local/bin, no Node
# dependency, self-updating). Belongs on every box including WSL.
install_claude_code() {
  command -v claude >/dev/null 2>&1 && return
  [[ -x "$HOME/.local/bin/claude" ]] && return
  log "Installing Claude Code"
  curl -fsSL https://claude.ai/install.sh | bash
}

# Sono monospace font. Not on Homebrew or in distro repos, so fetch the static
# weights from the source repo. macOS → ~/Library/Fonts; Linux desktop → XDG
# fonts dir. (WSL is skipped — its terminal and fonts live on Windows.)
install_fonts() {
  local dest
  case "$(uname -s)" in
    Darwin) dest="$HOME/Library/Fonts" ;;
    Linux)
      command -v fc-cache >/dev/null 2>&1 || { log "fontconfig missing; skipping fonts"; return; }
      dest="$FONTS_DIR/Sono" ;;
    *) return ;;
  esac
  [[ -e "$dest/Sono-Regular.ttf" ]] && return   # already installed
  log "Installing Sono font to $dest"
  mkdir -p "$dest"
  local w
  for w in ExtraLight Light Regular Medium SemiBold Bold ExtraBold; do
    curl -fsSL -o "$dest/Sono-$w.ttf" "$SONO_BASE/Sono-$w.ttf" || log "  (failed: Sono-$w)"
  done
  [[ "$(uname -s)" == "Linux" ]] && fc-cache -f "$FONTS_DIR" >/dev/null 2>&1
}

# git-delta: syntax-highlighting pager for git diffs. apt/brew provide it; not in
# Rocky/EPEL, so there we drop a pinned prebuilt binary into ~/.local/bin.
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
  local tmp; tmp="$(mktemp -d)"; TMPDIRS+=("$tmp")
  if curl -fsSL -o "$tmp/delta.tar.gz" \
      "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/${pkg}.tar.gz"; then
    tar -xzf "$tmp/delta.tar.gz" -C "$tmp"
    mkdir -p "$HOME/.local/bin"
    install -m 0755 "$tmp/$pkg/delta" "$HOME/.local/bin/delta"
  else
    log "delta download failed; skipping"
  fi
}

# sqlcmd (go-sqlcmd): Microsoft's modern single-binary SQL Server CLI — no ODBC
# stack, no MS repo, no EULA gate (MIT-licensed). Chosen over classic
# mssql-tools18 because we don't need bcp or AD-integrated (Kerberos) auth; the
# two can coexist later if that changes (classic lives in /opt/mssql-tools18).
# macOS gets it from the Brewfile; Linux drops the pinned release binary into
# ~/.local/bin (same pattern as delta).
install_sqlcmd() {
  command -v sqlcmd >/dev/null 2>&1 && return
  [[ -x "$HOME/.local/bin/sqlcmd" ]] && return
  [[ "$(uname -s)" == "Darwin" ]] && return   # Brewfile provides it
  local arch
  case "$(uname -m)" in
    x86_64)        arch="amd64" ;;   # release assets use Go arch names
    aarch64|arm64) arch="arm64" ;;
    *) log "Unknown arch $(uname -m); skipping sqlcmd"; return ;;
  esac
  command -v bzip2 >/dev/null 2>&1 || { log "bzip2 missing; skipping sqlcmd"; return; }
  log "Installing sqlcmd (go-sqlcmd) ${SQLCMD_VERSION} to ~/.local/bin"
  local tmp; tmp="$(mktemp -d)"; TMPDIRS+=("$tmp")
  if curl -fsSL -o "$tmp/sqlcmd.tar.bz2" \
      "https://github.com/microsoft/go-sqlcmd/releases/download/${SQLCMD_VERSION}/sqlcmd-linux-${arch}.tar.bz2"; then
    tar -xjf "$tmp/sqlcmd.tar.bz2" -C "$tmp"
    if [[ -f "$tmp/sqlcmd" ]]; then
      mkdir -p "$HOME/.local/bin"
      install -m 0755 "$tmp/sqlcmd" "$HOME/.local/bin/sqlcmd"
    else
      log "sqlcmd binary not found in the archive; skipping"
    fi
  else
    log "sqlcmd download failed; skipping"
  fi
}

# AWS CLI v2: installed user-space via AWS's official bundled installer on Linux
# (macOS gets it from the Brewfile). Tracks latest v2 — same as `brew "awscli"` —
# so both platforms stay on the current major version rather than the distro v1.
install_awscli() {
  command -v aws >/dev/null 2>&1 && return
  [[ -x "$HOME/.local/bin/aws" ]] && return
  [[ "$(uname -s)" == "Darwin" ]] && return   # provided by the Brewfile
  local arch
  case "$(uname -m)" in
    x86_64)        arch="x86_64" ;;
    aarch64|arm64) arch="aarch64" ;;
    *) log "Unknown arch $(uname -m); skipping AWS CLI"; return ;;
  esac
  command -v unzip >/dev/null 2>&1 || { log "unzip missing; skipping AWS CLI"; return; }
  log "Installing AWS CLI v2 (${arch}) to ~/.local/aws-cli"
  local tmp; tmp="$(mktemp -d)"; TMPDIRS+=("$tmp")
  if curl -fsSL -o "$tmp/awscliv2.zip" \
      "https://awscli.amazonaws.com/awscli-exe-linux-${arch}.zip"; then
    unzip -q "$tmp/awscliv2.zip" -d "$tmp"
    mkdir -p "$HOME/.local/bin"
    # --update lets a re-run replace a prior install instead of erroring; the
    # early returns above already short-circuit the normal "already installed"
    # case, so this only matters for a partial/corrupted prior install.
    if [[ -d "$HOME/.local/aws-cli" ]]; then
      "$tmp/aws/install" --update --install-dir "$HOME/.local/aws-cli" --bin-dir "$HOME/.local/bin"
    else
      "$tmp/aws/install" --install-dir "$HOME/.local/aws-cli" --bin-dir "$HOME/.local/bin"
    fi
  else
    log "AWS CLI download failed; skipping"
  fi
}

# ripsecrets: the pre-commit secret scanner (see .githooks/pre-commit). brew has
# it; apt/dnf don't, so Linux gets the pinned prebuilt release binary. Releases
# only ship x86_64 for Linux — other arches skip (the hook warns, not blocks).
install_ripsecrets() {
  command -v ripsecrets >/dev/null 2>&1 && return
  [[ -x "$HOME/.local/bin/ripsecrets" ]] && return
  [[ "$(uname -s)" == "Darwin" ]] && return   # Brewfile provides it
  if [[ "$(uname -m)" != "x86_64" ]]; then
    log "No ripsecrets release binary for $(uname -m); skipping (the hook will warn)"
    return
  fi
  local pkg="ripsecrets-${RIPSECRETS_VERSION}-x86_64-unknown-linux-gnu"
  log "Installing ripsecrets ${RIPSECRETS_VERSION} to ~/.local/bin"
  local tmp; tmp="$(mktemp -d)"; TMPDIRS+=("$tmp")
  if curl -fsSL -o "$tmp/ripsecrets.tar.gz" \
      "https://github.com/sirwart/ripsecrets/releases/download/v${RIPSECRETS_VERSION}/${pkg}.tar.gz"; then
    tar -xzf "$tmp/ripsecrets.tar.gz" -C "$tmp"
    local bin
    bin="$(find "$tmp" -name ripsecrets -type f | head -1)"
    if [[ -n "$bin" ]]; then
      mkdir -p "$HOME/.local/bin"
      install -m 0755 "$bin" "$HOME/.local/bin/ripsecrets"
    else
      log "ripsecrets binary not found in the archive; skipping"
    fi
  else
    log "ripsecrets download failed; skipping"
  fi
}

# Wait briefly for the local PostgreSQL server to accept connections — it may
# still be starting right after `systemctl enable --now` / `brew services start`.
pg_wait_ready() {
  local pg_isready="${1:-pg_isready}"
  for _ in 1 2 3 4 5; do
    "$pg_isready" -q 2>/dev/null && return 0
    sleep 1
  done
  return 1
}

# PostgreSQL local server. The PACKAGES come from the OS package lists; this
# handles the once-per-machine setup, idempotently:
#   Rocky:  postgresql-setup --initdb (guarded) + enable the systemd unit
#   Ubuntu: cluster/service handled by apt's postinst; nothing to do here
#   macOS:  brew services start (the formula initdb's on install)
# Then, everywhere: make a bare `psql` work for the login user. psql's defaults
# are user=$USER, dbname=$USER, and the stock pg_hba.conf is peer/ident — so we
# create that role (with CREATEDB) and database. On macOS brew's initdb already
# made the login user the superuser, so only the database is missing.
setup_postgresql() {
  case "$(uname -s)" in
    Darwin)
      command -v brew >/dev/null 2>&1 || return 0
      local pgbin; pgbin="$(brew --prefix)/opt/postgresql@16/bin"
      [[ -x "$pgbin/psql" ]] || return 0
      if ! brew services list 2>/dev/null | grep -qE '^postgresql@16\s+started'; then
        log "Starting postgresql@16 via brew services"
        brew services start postgresql@16 || true
      fi
      pg_wait_ready "$pgbin/pg_isready" \
        || { log "PostgreSQL not accepting connections yet; re-run bootstrap for the $USER database"; return 0; }
      if ! "$pgbin/psql" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$USER'" | grep -q 1; then
        log "Creating database $USER"
        "$pgbin/createdb" "$USER"
      fi
      ;;
    Linux)
      # postgresql-setup exists only on dnf boxes; Debian/Ubuntu self-manage.
      command -v postgresql-setup >/dev/null 2>&1 || return 0
      # PG_VERSION lives in a 700 postgres-owned dir, so test it as root.
      if ! sudo test -f /var/lib/pgsql/data/PG_VERSION; then
        log "Initializing the PostgreSQL data directory"
        sudo postgresql-setup --initdb
      fi
      if ! systemctl is-enabled --quiet postgresql 2>/dev/null; then
        log "Enabling postgresql.service"
        sudo systemctl enable --now postgresql || true
      fi
      pg_wait_ready \
        || { log "PostgreSQL not accepting connections yet; re-run bootstrap for the $USER role/db"; return 0; }
      if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$USER'" | grep -q 1; then
        log "Creating PostgreSQL role $USER (CREATEDB)"
        sudo -u postgres createuser --createdb "$USER"
      fi
      if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$USER'" | grep -q 1; then
        log "Creating database $USER"
        sudo -u postgres createdb -O "$USER" "$USER"
      fi
      ;;
  esac
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
  # --restow (-R) reconciles $HOME to each layer's current contents, so re-runs
  # converge (idempotent toward deletions, not just additions).
  log "Restowing layers: $*"
  stow --restow --verbose --target "$HOME" "$@"
}

main() {
  set -euo pipefail
  cd "$DOTFILES"
  trap cleanup EXIT

  # Enable this repo's ShellCheck pre-commit hook (see .githooks/).
  git config core.hooksPath .githooks 2>/dev/null || true

  case "$(uname -s)" in
    Darwin)
      install_macos_packages
      install_neovim
      install_antidote
      install_fonts
      install_claude_code
      stow_layers common macos
      ;;
    Linux)
      install_linux_packages
      install_neovim
      install_starship
      install_antidote
      install_mise
      install_delta
      install_awscli
      install_sqlcmd
      install_ripsecrets
      install_claude_code
      if is_wsl; then
        stow_layers common linux wsl
      else
        install_fonts               # Linux desktop only (WSL fonts live on Windows)
        stow_layers common linux
        # Opt-in, machine-specific provisioning kept out of this unattended flow
        # (see scripts/): setup-nvidia-rocky.sh (proprietary GPU driver, reboots),
        # disable-iscsi-offload-rocky.sh (silence cnic/bnx2i driver warnings).
      fi
      ;;
    *)
      die "Unsupported OS: $(uname -s)"
      ;;
  esac

  # One-time local PostgreSQL server setup (packages came from the lists above).
  setup_postgresql

  # Install language runtimes declared in the (now-stowed) mise global config.
  local mise_bin
  mise_bin="$(command -v mise 2>/dev/null || true)"
  [[ -z "${mise_bin:-}" && -x "$HOME/.local/bin/mise" ]] && mise_bin="$HOME/.local/bin/mise"
  if [[ -n "${mise_bin:-}" ]]; then
    log "Installing language runtimes via mise (node, …)"
    "$mise_bin" install || true
  fi

  # Build bat's theme cache so the tracked kanagawa theme is available.
  local bat_bin
  bat_bin="$(command -v bat 2>/dev/null || command -v batcat 2>/dev/null || true)"
  [[ -n "${bat_bin:-}" ]] && "$bat_bin" cache --build >/dev/null 2>&1

  # Nudge to make zsh the login shell (skipped if already zsh).
  if command -v zsh >/dev/null 2>&1 && [[ "${SHELL:-}" != *zsh ]]; then
    log "To make zsh your login shell:  chsh -s \"\$(command -v zsh)\""
  fi

  log "Done. Open a new zsh shell to load the config."
}

# Run only when executed directly, not when sourced (e.g. by the Bats tests).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
