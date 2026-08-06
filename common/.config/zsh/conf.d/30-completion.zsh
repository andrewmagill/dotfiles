# Completion system. zsh-completions (loaded by antidote in .zshrc) has already
# extended $fpath, so compinit picks up its definitions here.
autoload -Uz compinit
_zcompdump="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
[[ -d "${_zcompdump:h}" ]] || mkdir -p "${_zcompdump:h}"
compinit -d "$_zcompdump"
unset _zcompdump

# Styling
zstyle ':completion:*' menu select                       # arrow-key menu
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' # case-insensitive
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}    # color the menu
