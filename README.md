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
| `opencode`   | `~/.config/opencode/` (config, skills, commands) |

`opencode/` tracks config + skills only; `node_modules`, lockfiles, and
`antigravity-accounts.json` stay machine-local (its own `.gitignore`).

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
`$DOTFILES_PROFILE`, falling back to the hostname (`PAI-*` → `work`, else `home`):

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
