# Pager: use bat for syntax highlighting in `less` (file arguments) and in man
# pages. On Debian/Ubuntu the binary is `batcat`; detect whichever exists.
if command -v bat >/dev/null 2>&1; then
  BAT=bat
elif command -v batcat >/dev/null 2>&1; then
  BAT=batcat
  alias bat=batcat            # so interactive `bat` works on Debian/Ubuntu too
fi

if [[ -n "${BAT:-}" ]]; then
  # less: highlights file ARGUMENTS (not piped input like `cmd | less`).
  export LESSOPEN="|${BAT} --color=always --paging=never --style=plain -- %s"
  export LESS="-R"
  # man pages: bat is the pager here, so let it page.
  export MANPAGER="sh -c 'col -bx | ${BAT} -l man -p'"
  export MANROFFOPT="-c"
fi
unset BAT
