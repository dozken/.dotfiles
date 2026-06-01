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
| `claude`     | `~/.claude/`                            |

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
