# History. HISTFILE is (re)set HERE, not only in .zshenv: the system /etc/zshrc
# on macOS and Debian/Ubuntu runs AFTER .zshenv and overrides HISTFILE to
# $ZDOTDIR/.zsh_history (= the stowed repo). This interactive fragment loads
# after /etc/zshrc, so re-asserting the XDG path here wins and keeps history out
# of the repo.
export HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
[[ -d "${HISTFILE:h}" ]] || mkdir -p "${HISTFILE:h}"

HISTSIZE=50000               # lines kept in memory
SAVEHIST=50000               # lines written to $HISTFILE

setopt SHARE_HISTORY         # share history live across running shells
setopt EXTENDED_HISTORY      # record timestamps
setopt HIST_IGNORE_DUPS      # don't record a command identical to the last
setopt HIST_IGNORE_SPACE     # a leading space keeps a command out of history
setopt HIST_REDUCE_BLANKS    # trim superfluous whitespace before saving
