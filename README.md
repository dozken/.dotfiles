# dotfiles

macOS dotfiles, managed with [GNU Stow](https://www.gnu.org/software/stow/).

Each top-level directory is a **stow package** whose contents mirror `$HOME`.
`stow zsh` symlinks `zsh/.zshrc` → `~/.zshrc`, `zsh/.config/starship.toml` →
`~/.config/starship.toml`, and so on.

## Layout

| Package      | Links into                              |
| ------------ | --------------------------------------- |
| `zsh`        | `~/.zshrc`, `~/.config/starship.toml`   |
| `tmux`       | `~/.config/tmux/`                       |
| `wezterm`    | `~/.config/wezterm/`                    |
| `karabiner`  | `~/.config/karabiner/`                  |
| `ideavimrc`  | `~/.ideavimrc`                          |
| `claude`     | `~/.claude/` (settings, keybindings)    |
| `agents`     | `~/.agents/skills/` (Claude skills)     |

Not stowed: `homebrew/` (Brewfile), `scripts/` (added to `PATH` from the repo),
`vial/` (keyboard layouts, imported manually).

## Bootstrap a new Mac

```zsh
# 1. Xcode command line tools (git, etc.)
xcode-select --install

# 2. Clone
git clone git@github.com:dozken/.dotfiles.git ~/.dotfiles

# 3. Install Homebrew + packages, then symlink everything
cd ~/.dotfiles && ./setup.sh
```

`setup.sh` is idempotent — re-run it any time to re-sync packages and symlinks.

## Homebrew profiles

Packages are split so each machine installs only what it needs:

| File                    | Installed on            |
| ----------------------- | ----------------------- |
| `homebrew/Brewfile`      | every machine (base)    |
| `homebrew/Brewfile.work` | work (java/gitlab/mobile/cloud) |
| `homebrew/Brewfile.home` | personal (media, extra runtimes) |

`setup.sh` installs the base then the active profile. The profile is chosen by
`$DOTFILES_PROFILE`, else the untracked file `~/.config/dotfiles/profile`
(`work` or `home`), else `home`:

```zsh
DOTFILES_PROFILE=home ./setup.sh          # force a profile

# resync a profile from the current machine's installed packages:
brew bundle dump --file=homebrew/Brewfile.work --force
```

## Secrets

`~/.zshrc` sources `~/.env.secrets` if it exists. Copy the template and fill it in:

```zsh
cp ~/.dotfiles/.env.secrets.example ~/.env.secrets   # then edit
```

`~/.env.secrets` is gitignored; only `.env.secrets.example` is tracked.

## Day-to-day

```zsh
cd ~/.dotfiles

stow <package>            # link one package        (e.g. stow tmux)
stow --restow <package>   # re-link after changes
stow -D <package>         # unlink a package
```

`.stowrc` sets `--target=..` (so packages land in `$HOME`) and `--no-folding`
(so e.g. `~/.config/tmux` stays a real dir and TPM plugins remain
machine-local, never written back into the repo).

## Keeping work and personal apart

This repo is **public** and used on both a personal and a work Mac, so nothing
secret or employer-specific may be committed.

- Secrets live only in untracked `~/.env.secrets` (per machine, never synced).
- The machine profile lives in untracked `~/.config/dotfiles/profile`.
- `scripts/git-hooks/pre-commit` (enabled by `setup.sh` via `core.hooksPath`)
  blocks staged secrets, key/env files, and anything matching your private
  denylist at `~/.config/dotfiles/denylist` (one regex per line: employer
  name, hostnames, internal domains). Create that file on each machine.
