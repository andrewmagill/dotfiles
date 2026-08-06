# Machine-local, untracked config: secrets, per-host overrides, work-only bits.
# These files live in $ZDOTDIR (which is OUTSIDE the dotfiles repo, so git can't
# reach them) and match .gitignore patterns as a backstop. Loads last so it can
# override anything above.
#
# Create as needed on a given machine, e.g.:
#   ~/.config/zsh/work.local.zsh   (per-machine overrides)
#   ~/.config/zsh/secrets.zsh      (secret env / lazy password-manager wrappers)
for _local in "$ZDOTDIR"/*.local.zsh(N) "$ZDOTDIR"/secrets.zsh(N); do
  source "$_local"
done
unset _local
