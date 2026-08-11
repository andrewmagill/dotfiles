# Machine-local, untracked INTERACTIVE config: per-host overrides, work-only
# bits, aliases. Lives in $ZSH_LOCAL_DIR, a directory OUTSIDE the stowed tree
# that Stow never links — so git genuinely can't reach it (unlike $ZDOTDIR,
# which is a tree-folded Stow symlink back INTO this repo). Loads last so it can
# override anything above.
#
# Only *.local.zsh is loaded here. Secrets are named *.secrets.zsh and loaded
# from .zshenv instead, so non-interactive shells get them too — this file is
# sourced by .zshrc, which ONLY interactive shells read. Putting a credential
# here means `ssh host 'cmd'`, cron, and GUI-launched tools silently see nothing.
#
# Create the dir and drop files in as needed on a given machine, e.g.:
#   ~/.config/zsh.local/work.local.zsh    (per-machine interactive overrides)
#   ~/.config/zsh.local/ado.secrets.zsh   (secret env — loaded from .zshenv)
: "${ZSH_LOCAL_DIR:=${XDG_CONFIG_HOME:-$HOME/.config}/zsh.local}"
for _local in "$ZSH_LOCAL_DIR"/*.local.zsh(N); do
  source "$_local"
done
unset _local
