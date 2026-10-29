#!/usr/bin/env bash
# One-line bootstrap for a fresh Arch install:
#   bash <(curl -fsSL https://raw.githubusercontent.com/Haddadmj/dotfiles/main/setup.sh)
set -euo pipefail
REPO=${REPO:-https://github.com/Haddadmj/dotfiles}
DIR=${DIR:-$HOME/dotfiles}
sudo pacman -S --needed --noconfirm git
if [[ -d $DIR/.git ]]; then git -C "$DIR" pull --ff-only; else git clone "$REPO" "$DIR"; fi
exec "$DIR/install.sh" "$@"
