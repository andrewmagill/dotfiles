# Machine-local, untracked config: secrets, per-host overrides, work-only bits.
# These live in $ZSH_LOCAL_DIR, a directory OUTSIDE the stowed tree that Stow
# never links — so git genuinely can't reach it (unlike $ZDOTDIR, which is a
# tree-folded Stow symlink back INTO this repo). Loads last so it can override
# anything above.
#
# Create the dir and drop files in as needed on a given machine, e.g.:
#   ~/.config/zsh.local/work.local.zsh   (per-machine overrides)
#   ~/.config/zsh.local/secrets.zsh      (secret env / lazy password-manager wrappers)
: "${ZSH_LOCAL_DIR:=${XDG_CONFIG_HOME:-$HOME/.config}/zsh.local}"
for _local in "$ZSH_LOCAL_DIR"/*.zsh(N); do
  source "$_local"
done
unset _local
