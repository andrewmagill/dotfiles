# mise — activate the polyglot runtime version manager. `mise activate` adds tool
# shims to PATH and installs a precmd hook so the right node/python/etc. version
# is selected per directory (.mise.toml / .tool-versions). Runs after compinit
# (30-completion.zsh) so its completions register cleanly.
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi
