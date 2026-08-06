# ~/.config/zsh/.zshrc — interactive shell configuration.
# Only interactive shells read this file.

# --- Plugins (antidote, static bundle) -------------------------------------
# antidote compiles .zsh_plugins.txt into a static, source-able script. We keep
# the GENERATED bundle in the cache dir (never in $ZDOTDIR) so the repo stays
# clean, and regenerate it only when the plugin list changes.
#
# Loaded BEFORE compinit (run in conf.d/30-completion.zsh) so zsh-completions can
# extend $fpath in time. In .zsh_plugins.txt, zsh-syntax-highlighting is listed
# last, as it requires.
ANTIDOTE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/antidote"
if [[ -r "$ANTIDOTE_DIR/antidote.zsh" ]]; then
  source "$ANTIDOTE_DIR/antidote.zsh"
  _plugins_txt="$ZDOTDIR/.zsh_plugins.txt"
  _plugins_zsh="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zsh_plugins.zsh"
  [[ -d "${_plugins_zsh:h}" ]] || mkdir -p "${_plugins_zsh:h}"
  if [[ ! "$_plugins_zsh" -nt "$_plugins_txt" ]]; then
    antidote bundle <"$_plugins_txt" >"$_plugins_zsh"
  fi
  source "$_plugins_zsh"
  unset _plugins_txt _plugins_zsh
fi

# --- Config fragments ------------------------------------------------------
# Sourced in numeric order. The (N) glob qualifier skips silently if nothing
# matches, so a missing/empty conf.d never errors.
for _f in "$ZDOTDIR"/conf.d/*.zsh(N); do
  source "$_f"
done
unset _f
