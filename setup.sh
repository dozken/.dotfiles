#!/usr/bin/env bash
stow --restow  .

ln -s ~/.config/zshrc/.zshrc ~/.zshrc
source ~/.zshrc

tmux source-file ~/.config/tmux/tmux.conf

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# xargs brew install < ./homebrew/leaves.txt
brew bundle --file=~/.config/homebrew/Brewfile


