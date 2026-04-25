#!/usr/bin/env bash

# Check if Homebrew is installed, install if not
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Run brew bundle
echo "Syncing Homebrew packages..."
brew bundle --file=./homebrew/Brewfile

# Use GNU Stow to link configurations
# This assumes you want things in ~/.config/
echo "Stowing configurations..."
stow --target="$HOME" .

# Ensure .zshrc is linked correctly (Stow handles this if structured right, 
# but your current structure has it in zshrc/.zshrc which stows to ~/.zshrc)
if [ ! -L "$HOME/.zshrc" ]; then
    echo "Fixing .zshrc symlink..."
    ln -sf "$HOME/.config/zshrc/.zshrc" "$HOME/.zshrc"
fi

# Apply macOS defaults (optional/manual trigger recommended)
read -p "Do you want to apply macOS system defaults? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ./scripts/.macos
fi

echo "Setup complete. Please restart your terminal."
