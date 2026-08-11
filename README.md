# dotfiles

Personal, cross-platform dotfiles managed with **[GNU Stow](https://www.gnu.org/software/stow/)**
and organized around the **[XDG Base Directory](https://specifications.freedesktop.org/basedir-spec/latest/)**
specification. One repository for three environments:

- **Rocky Linux** — desktop
- **macOS** (Apple Silicon) — laptop
- **Ubuntu on WSL2** — Windows work machine

## Goals

- **Simple and transparent.** Files symlinked into place by Stow — no
  framework, everything is easily greppable and inspectable.
- **One repo, per-OS layers.** Shared config in `common/`; OS-specific in `linux/`, 
  `macos/`, and `wsl/`. You link the layers your machine needs.
- **XDG-clean `$HOME`.** Config under `~/.config`, data under `~/.local/share`,
  state under `~/.local/state`, cache under `~/.cache`.
- **No secrets in the repo.** Anything secret or machine-specific lives in 
  untracked local files that never get committed (see [Secrets](#secrets)).
- **Reproducible bootstrap.** One script installs packages and links configs on
  a fresh machine.

## Layout

```
dotfiles/
├── bootstrap.sh          # detect OS/distro/WSL → install packages → stow layers
├── packages/             # what to install, per package manager
│   ├── Brewfile          #   macOS        (brew bundle)
│   ├── apt.txt           #   Debian/Ubuntu (apt — used by WSL)
│   └── dnf.txt           #   Rocky Linux  (dnf)
├── common/               # Stow layer: config shared by every machine
├── linux/                # Stow layer: all Linux (Rocky desktop + WSL)
├── macos/                # Stow layer: macOS only
└── wsl/                  # Stow layer: WSL-only extras
```

Each Stow *layer* mirrors the structure of `$HOME`. For example,
`common/.config/zsh/.zshrc` becomes a symlink at `~/.config/zsh/.zshrc`.

## Install

```bash
git clone <this-repo> ~/dotfiles
cd ~/dotfiles
./bootstrap.sh
```

`bootstrap.sh` detects the OS (and, on Linux, the package manager and whether
it's running under WSL), installs the listed packages **plus pinned prebuilt
tools** (Neovim, Starship, mise, git-delta) and the Nerd Font, then symlinks the
right layers with Stow. It's re-runnable — each step is guarded, and Stow uses
`--restow`.

To link by hand instead:

| Machine              | Command                          |
| -------------------- | -------------------------------- |
| Rocky Linux desktop  | `stow -t ~ common linux`         |
| macOS                | `stow -t ~ common macos`         |
| Ubuntu on WSL2       | `stow -t ~ common linux wsl`     |

## What's configured

| Area | Tools | Highlights |
| ---- | ----- | ---------- |
| **Shell** | zsh, Starship, antidote | XDG-relocated `ZDOTDIR`, numbered `conf.d/` fragments, plugins (autosuggestions, syntax-highlighting, completions) |
| **Editor** | Neovim (pinned **0.11.7**) | lazy.nvim; LSP via mason + lspconfig (lua_ls, TypeScript); blink.cmp completion; Treesitter; Telescope; kanagawa colorscheme |
| **Runtimes** | mise | tool versions declared in `~/.config/mise/config.toml` (Node LTS today) |
| **Terminals** | Alacritty, kitty, WezTerm, Windows Terminal | all themed with the **SeaShells** palette |
| **Pager / diff** | bat, git-delta | syntax highlighting in `less`, `man`, and `git diff/show` — kanagawa theme matching Neovim |
| **Font** | OpenDyslexic Nerd Font | installed per-OS, selected in each terminal |

**How things get installed.** Packaged tools come from each OS's list under
`packages/`. Tools that aren't reliably packaged — **Neovim, Starship, mise,
git-delta** — are installed as **pinned prebuilt binaries** into `~/.local/bin`
(user-space, no sudo), so every machine runs the same version.

> **Why Neovim is pinned to 0.11.7:** nvim-treesitter's frozen `master` branch is
> incompatible with Neovim 0.12's treesitter core (it breaks markdown
> highlighting). We'll un-pin once we migrate to nvim-treesitter's `main` branch.

## Organization

### Stow layers

Stow "packages" (aka *layers*) are directories whose contents get symlinked into `$HOME`,
package specific configs are symlinked only in their target environments.

### Package lists

Installation is separate from linking. Each package manager has its own list:

- **macOS** → `packages/Brewfile` (`brew bundle`)
- **Ubuntu/Debian (WSL)** → `packages/apt.txt`
- **Rocky** → `packages/dnf.txt`

## Zsh configuration

Zsh reads up to **five** startup files, along two axes — *login vs. not* and
*interactive vs. not*:

| File          | Read for…                                            | When              |
| ------------- | ---------------------------------------------------- | ----------------- |
| `.zshenv`     | **every** invocation (scripts, cron, interactive…)   | 1st, always       |
| `.zprofile`   | **login** shells only                                | before `.zshrc`   |
| `.zshrc`      | **interactive** shells only                          | 3rd               |
| `.zlogin`     | **login** shells only                                | after `.zshrc`    |
| `.zlogout`    | **login** shells only                                | at logout         |

**Rules of thumb for what goes where:**

- **`.zshenv`** — *environment* that every shell (including scripts and
  GUI-launched programs) must see: `PATH`, the XDG variables, `ZDOTDIR`, and tool
  env like `EDITOR`. Keep it fast and side-effect-free.
- **`.zshrc`** — *interactive* experience: prompt, aliases, keybindings,
  completion, functions.
- **`.zprofile` / `.zlogin` / `.zlogout`** — login-only hooks; most setups don't
  need them. Reach for `.zprofile` only for "once per login" tasks (e.g. starting
  an agent).

Because zsh reads `.zshenv` from `$HOME` *before* `ZDOTDIR` is known, a tiny
`~/.zshenv` stub sets `ZDOTDIR="$XDG_CONFIG_HOME/zsh"` so every *other* zsh file
lives under `~/.config/zsh/` and `$HOME` stays clean.

### The `conf.d` pattern

Rather than one giant `.zshrc`, interactive config is split into numbered
fragments that are sourced in order:

```
~/.config/zsh/
├── .zshenv           # environment (XDG paths, PATH, tool env)
├── .zshrc            # sources everything in conf.d/
├── conf.d/
│   ├── 00-options.zsh
│   ├── 10-history.zsh
│   ├── 20-prompt.zsh
│   ├── 30-completion.zsh
│   ├── 40-keybindings.zsh
│   ├── 50-aliases.zsh
│   └── 90-local.zsh   # machine-local hook (loads last; secrets wiring lives here)
└── functions/         # autoloaded functions, one per file
```

`.zshrc` is essentially just:

```zsh
for f in "$ZDOTDIR"/conf.d/*.zsh; do source "$f"; done
```

The numeric prefixes set load order without any plugin framework.

> **The `.d` convention:** the trailing `.d` in `conf.d` means **"directory"** —
> a directory of drop-in fragments that together make up one logical config.
> It's the same idea as `/etc/cron.d`, `/etc/profile.d`, and
> `/etc/systemd/system/*.d`. Add a file to add config; delete it to remove it.
> (It is *not* short for "daemon" — that's the trailing `d` in program names like
> `sshd`.)

### Zsh concepts used here

A few zsh-specific mechanisms appear throughout the config:

- **`$fpath`** — zsh's *function* search path (the analog of `$PATH` for
  executables). Autoloadable functions and completion definitions are found here;
  the `zsh-completions` plugin simply prepends to it.
- **`autoload -Uz name`** — lazily load a function from `$fpath` on first use.
  `-U` suppresses alias expansion in its body, `-z` forces zsh-style — the safe,
  standard flags. Used for `compinit`.
- **`compinit`** — initializes the completion system by scanning `$fpath`, and
  caches an index under `$XDG_CACHE_HOME`. It must run *after* anything that
  extends `$fpath`, which is why `.zshrc` loads antidote before
  `conf.d/30-completion.zsh`.
- **`zle` / widgets** — the Zsh Line Editor and its key-bound commands.
  `bindkey -e` selects emacs-style widgets; `zsh-syntax-highlighting` hooks zle
  and so must load last.
- **`setopt`** — toggles named shell options (`AUTO_CD`, `SHARE_HISTORY`, …).
- **`zstyle`** — zsh's hierarchical config database, used to tune completion
  (e.g. `zstyle ':completion:*' menu select`).
- **Glob qualifiers / flags** — `*.zsh(N)` expands to nothing if there's no match
  (nullglob); `${(s.:.)VAR}` splits a value on `:`; `${(P)var}` is indirect
  (value-as-name).
- **Parameter modifiers** — `${file:h}` is the directory part (like `dirname`),
  `:t` the basename, `:r` strips the extension.
- **`typeset -U path PATH`** — keeps `$PATH` unique; zsh ties the `$path` array to
  the `$PATH` string, so you can edit either.

## Secrets

This repo is public, so **nothing secret ever lives in it**. Two mechanisms:

1. **Untracked local files.** Tracked config sources machine-local files from
   `~/.config/zsh.local/` (`$ZSH_LOCAL_DIR`) — a directory *outside* the stowed
   tree that Stow never links, so `git` genuinely can't reach it. This matters:
   `~/.config/zsh` itself is a tree-folded Stow symlink back **into** this repo,
   so a file dropped there (e.g. `~/.config/zsh/secrets.zsh`) would land in the
   repo's working tree — caught only by `.gitignore`. Keeping locals in a
   sibling `zsh.local/` dir removes that trap. `.gitignore` still blocks
   secret-shaped filenames as a backstop.

   **The filename picks the load site**, so name files by what they hold:

   | Name | Loaded by | Seen by | For |
   | ---- | --------- | ------- | --- |
   | `*.secrets.zsh` | `.zshenv` | **every** zsh | secret env vars |
   | `*.local.zsh` | `conf.d/90-local.zsh` | interactive only | prompt, aliases, per-host overrides |

   **Rule: anything holding a credential is named `*.secrets.zsh`.** Two reasons.
   It loads from `.zshenv`, so non-interactive shells — and anything they spawn,
   like MCP servers, `cron`, `ssh host 'cmd'`, or a GUI-launched editor — also see
   the value; a credential in `*.local.zsh` is invisible to all of those, and
   fails *silently*. And it matches the `*.secrets.zsh` pattern in `.gitignore`,
   so the backstop still works if the file is ever copied into the repo. Keep
   these files to plain `export` literals with no subshells: `.zshenv` runs for
   every zsh invocation on the machine, including every script.

   Neither glob matches a bare name like `ado.zsh`, and `(N)` makes a
   no-match expand to nothing — so a misnamed file is skipped in silence.
2. **Lazy secret fetching.** For values kept in a password manager, a small
   wrapper fetches the secret from the vault the first time a tool needs it and
   caches it for the session — nothing on disk, nothing committable, no shell
   startup cost. Only the *reference* (not the value) ever appears in tracked
   files, and anything work-identifying stays in an untracked `*.local.zsh`.

## Roadmap

- [ ] More languages via mise + LSP: C# (.NET), Python, SQL (PostgreSQL / SQL Server), Terraform
- [ ] Neovim: formatting (conform.nvim), git signs, statusline (lualine), a DAP debugger
- [ ] Migrate nvim-treesitter to the `main` branch (would let us un-pin Neovim from 0.11)
- [ ] Custom login flavor (motd / `profile.d`)
- [ ] Thin Windows-native layer (Windows Terminal, PowerShell profile)
- [ ] Nix / Home Manager — declarative, fully-pinned reproducibility (the eventual endgame)
- [ ] Tiling Wayland compositor (Sway / Hyprland) — someday
