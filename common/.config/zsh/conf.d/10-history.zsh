# History. HISTFILE itself is set in .zshenv (it's environment); the behavior
# below is interactive-only.
HISTSIZE=50000               # lines kept in memory
SAVEHIST=50000               # lines written to $HISTFILE

setopt SHARE_HISTORY         # share history live across running shells
setopt EXTENDED_HISTORY      # record timestamps
setopt HIST_IGNORE_DUPS      # don't record a command identical to the last
setopt HIST_IGNORE_SPACE     # a leading space keeps a command out of history
setopt HIST_REDUCE_BLANKS    # trim superfluous whitespace before saving
