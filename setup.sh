#!/usr/bin/env bash
# Bootstrap / re-sync this machine from the dotfiles repo. Idempotent:
# safe to run repeatedly.
set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/.dotfiles}"
cd "$DOTFILES"

# Stow packages. Each is a dir whose contents mirror $HOME.
PACKAGES=(zsh tmux wezterm karabiner ideavimrc claude)

info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }

# 1. Homebrew + Brewfile ------------------------------------------------
if ! command -v brew >/dev/null 2>&1; then
  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
# Pick profile: $DOTFILES_PROFILE, else by hostname (work Macs are PAI-*).
PROFILE="${DOTFILES_PROFILE:-}"
if [[ -z "$PROFILE" ]]; then
  case "$(hostname -s)" in
    PAI-*) PROFILE=work ;;
    *)     PROFILE=home ;;
  esac
fi
info "Syncing Homebrew packages (base + $PROFILE)..."
brew bundle --file=homebrew/Brewfile
[[ -f "homebrew/Brewfile.$PROFILE" ]] && brew bundle --file="homebrew/Brewfile.$PROFILE"

command -v stow >/dev/null 2>&1 || brew install stow

# 2. Remove stale symlinks from the old `stow .` layout -----------------
# Those linked whole package dirs (and junk like setup.sh) into ~/.config.
info "Cleaning legacy ~/.config symlinks..."
for link in "$HOME"/.config/*; do
  if [[ -L "$link" && "$(readlink "$link")" == *.dotfiles* ]]; then
    rm -f "$link"
  fi
done

# 3. Pre-create real target dirs so stow links files, never folds a whole
#    dir into the repo (keeps room for machine-local data like TPM plugins).
mkdir -p "$HOME/.config/tmux" "$HOME/.config/wezterm" \
         "$HOME/.config/karabiner" "$HOME/.claude"

# 4. Stow everything (--restow re-links cleanly on every run) ------------
info "Stowing: ${PACKAGES[*]}"
stow --restow "${PACKAGES[@]}"

# 5. macOS defaults (opt-in) --------------------------------------------
read -rp "Apply macOS system defaults? (y/N) " reply
if [[ ${reply:-} =~ ^[Yy]$ ]]; then
  ./scripts/.macos
fi

info "Done. Start a fresh shell:  exec zsh"
