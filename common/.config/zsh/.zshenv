# ~/.config/zsh/.zshenv — environment for ALL zsh invocations (scripts, cron,
# interactive, login). Sourced from the ~/.zshenv stub. Keep it fast and
# side-effect-light: no output, no slow subshells.

# --- XDG base directories --------------------------------------------------
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# --- Default programs ------------------------------------------------------
export EDITOR="nvim"
export VISUAL="nvim"
export PAGER="less"

# --- Relocate non-XDG-aware tools out of $HOME -----------------------------
# HISTFILE is ALSO re-asserted in conf.d/10-history.zsh, because the system
# /etc/zshrc (macOS, Debian/Ubuntu) overrides it after this file runs.
export HISTFILE="$XDG_STATE_HOME/zsh/history"
export LESSHISTFILE="$XDG_STATE_HOME/less/history"
[[ -d "$XDG_STATE_HOME/zsh" ]] || mkdir -p "$XDG_STATE_HOME/zsh"
# macOS Terminal saves shell sessions into $ZDOTDIR/.zsh_sessions (= the stowed
# repo). Disable it — harmless no-op on Linux.
export SHELL_SESSIONS_DISABLE=1

# --- Machine-local secrets -------------------------------------------------
# $ZSH_LOCAL_DIR holds untracked machine-local config. It defaults to
# ~/.config/zsh.local — a sibling of $ZDOTDIR that Stow never links, so git
# genuinely cannot reach it. ($ZDOTDIR itself is a tree-folded Stow symlink
# back INTO the repo, which is why locals don't live there. See
# conf.d/90-local.zsh and the README's Secrets section.)
#
# Filename picks the load site, so put each file where its purpose needs it:
#   *.secrets.zsh   secret env vars — loaded HERE, so non-interactive shells
#                   and anything they spawn (MCP servers, cron, ssh 'cmd',
#                   editors, scripts) see the values too.
#   *.local.zsh     interactive overrides — loaded from conf.d/90-local.zsh,
#                   which runs last so it can override the prompt, aliases, etc.
# Keep *.secrets.zsh to plain `export` literals: this file runs for EVERY zsh,
# so a subshell in here is a cost paid by every script on the machine.
: "${ZSH_LOCAL_DIR:=${XDG_CONFIG_HOME:-$HOME/.config}/zsh.local}"
export ZSH_LOCAL_DIR
for _secret in "$ZSH_LOCAL_DIR"/*.secrets.zsh(N); do
  source "$_secret"
done
unset _secret

# --- PATH ------------------------------------------------------------------
typeset -U path PATH                        # keep PATH entries unique
# Homebrew on Apple Silicon first (no-op elsewhere), THEN prepend ~/.local/bin so
# our pinned prebuilt tools (nvim, mise, delta, …) take precedence over brew.
[[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
# postgresql@16 is keg-only (brew doesn't link versioned formulas), so psql &
# friends need an explicit PATH entry. No-op on Linux and pg-less Macs.
[[ -d /opt/homebrew/opt/postgresql@16/bin ]] && path=("/opt/homebrew/opt/postgresql@16/bin" $path)
[[ -d "$HOME/.local/bin" ]] && path=("$HOME/.local/bin" $path)
export PATH
