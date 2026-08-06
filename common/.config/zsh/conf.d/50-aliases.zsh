# Aliases. Kept minimal for now — a fuller pass comes later.

# `o <thing>` opens files/URLs with the OS handler. ls color flags differ too:
# GNU ls uses --color, BSD/macOS ls uses -G.
case "$OSTYPE" in
  darwin*)
    alias o='open'
    alias ls='ls -G'
    ;;
  linux*)
    alias o='xdg-open'
    alias ls='ls --color=auto'
    ;;
esac

alias ll='ls -lah'
alias la='ls -A'
alias grep='grep --color=auto'
