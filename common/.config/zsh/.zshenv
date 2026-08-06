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
export HISTFILE="$XDG_STATE_HOME/zsh/history"
export LESSHISTFILE="$XDG_STATE_HOME/less/history"
[[ -d "$XDG_STATE_HOME/zsh" ]] || mkdir -p "$XDG_STATE_HOME/zsh"

# --- PATH ------------------------------------------------------------------
typeset -U path PATH                        # keep PATH entries unique
[[ -d "$HOME/.local/bin" ]] && path=("$HOME/.local/bin" $path)
# Homebrew on Apple Silicon (no-op elsewhere)
[[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
export PATH
