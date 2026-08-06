# ~/.zshenv — the ONLY zsh file that must live in $HOME.
#
# zsh reads this before ZDOTDIR is known (ZDOTDIR defaults to $HOME here), so we
# use it to point ZDOTDIR at the XDG location and then load the real environment.
# Every other zsh file ($ZDOTDIR/.zshrc, .zprofile, …) then lives under
# ~/.config/zsh, keeping $HOME clean.
export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
[[ -r "$ZDOTDIR/.zshenv" ]] && source "$ZDOTDIR/.zshenv"
