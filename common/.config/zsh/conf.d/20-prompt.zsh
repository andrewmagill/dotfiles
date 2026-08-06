# Prompt — Starship (https://starship.rs). Config lives in ~/.config/starship.toml.
# Guarded so a shell still works on a machine where starship isn't installed yet.
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi
