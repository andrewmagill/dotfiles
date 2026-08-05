# dotfiles

Personal, cross-platform dotfiles managed with **[GNU Stow](https://www.gnu.org/software/stow/)**
and organized around the **[XDG Base Directory](https://specifications.freedesktop.org/basedir-spec/latest/)**
specification. One repository drives three environments:

- 🐧 **Rocky Linux** — desktop
- 🍎 **macOS** (Apple Silicon) — laptop
- 🪟 **Ubuntu on WSL2** — Windows work machine

## Philosophy

- **Simple and transparent.** Real files, symlinked into place by Stow — no
  framework, no magic, everything is greppable and inspectable.
- **One repo, per-OS layers.** Shared config lives in `common/`; OS-specific
  bits live in `linux/`, `macos/`, and `wsl/`. You link the layers your machine
  needs.
- **XDG-clean `$HOME`.** Config under `~/.config`, data under `~/.local/share`,
  state under `~/.local/state`, cache under `~/.cache`. `$HOME` stays tidy.
- **No secrets in the repo.** This repository is **public**. Anything secret or
  machine-specific lives in untracked local files that never get committed
  (see [Secrets](#secrets)).
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
├── wsl/                  # Stow layer: WSL-only extras
└── notes/                # reference notes (not stowed)
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
it's running under WSL), installs the listed packages, then symlinks the right
layers with Stow.

To link by hand instead:

| Machine              | Command                          |
| -------------------- | -------------------------------- |
| Rocky Linux desktop  | `stow -t ~ common linux`         |
| macOS                | `stow -t ~ common macos`         |
| Ubuntu on WSL2       | `stow -t ~ common linux wsl`     |

## How it's organized

### Stow layers

Stow "packages" (here called *layers*) are just directories whose contents get
symlinked into `$HOME`. Splitting by OS keeps each file free of the platform it
doesn't apply to — a macOS-only `karabiner` config never appears on Linux, and a
Linux-only `systemd` unit never appears on the Mac. Small per-OS differences
*inside* a shared file (e.g. `open` vs `xdg-open`) are handled with a `case`
statement rather than a whole separate file.

### Package lists

Installation is separate from linking. Each package manager has its own list so
"what should be installed" is itself version-controlled:

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

## Secrets

This repo is public, so **nothing secret ever lives in it**. Two mechanisms:

1. **Untracked local files.** Tracked config sources a machine-local file that
   lives *outside* the repo (e.g. `~/.config/zsh/secrets.zsh`), so `git` can't
   reach it. `.gitignore` blocks secret-shaped filenames as a backstop.
2. **Lazy secret fetching.** For values kept in a password manager, a small
   wrapper fetches the secret from the vault the first time a tool needs it and
   caches it for the session — nothing on disk, nothing committable, no shell
   startup cost. Only the *reference* (not the value) ever appears in tracked
   files, and anything work-identifying stays in an untracked `*.local.zsh`.

## Roadmap

- [ ] Zsh config files (`.zshenv` / `.zshrc` / `conf.d/`)
- [ ] Language tooling: .NET/C#, Node/TypeScript, SQL (PostgreSQL + SQL Server)
- [ ] Neovim configuration
- [ ] Custom login flavor (motd / `profile.d`)
- [ ] Thin Windows-native layer (Windows Terminal, PowerShell)
- [ ] Nix / Home Manager (future, for fully reproducible packages)
- [ ] Tiling Wayland compositor (Sway / Hyprland) — someday

## Notes

Background reference material lives in [`notes/`](notes/) — e.g. the Linux
login/boot flow, PAM, X11 vs Wayland, and the `.d` naming convention.
