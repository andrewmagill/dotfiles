# ~/.config/zsh/.zshrc — interactive shell configuration.
# Only interactive shells read this file.

# --- Plugins (antidote) ----------------------------------------------------
# Loaded BEFORE compinit (run in conf.d/30-completion.zsh) so that
# zsh-completions can extend $fpath in time. antidote reads the plugin list in
# .zsh_plugins.txt; zsh-syntax-highlighting is listed last, as it requires.
ANTIDOTE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/antidote"
if [[ -r "$ANTIDOTE_DIR/antidote.zsh" ]]; then
  source "$ANTIDOTE_DIR/antidote.zsh"
  antidote load "$ZDOTDIR/.zsh_plugins.txt"
fi

# --- Config fragments ------------------------------------------------------
# Sourced in numeric order. The (N) glob qualifier skips silently if nothing
# matches, so a missing/empty conf.d never errors.
for _f in "$ZDOTDIR"/conf.d/*.zsh(N); do
  source "$_f"
done
unset _f
