#!/usr/bin/env bash
#
# Symlink this repo's files into place.
#
#   ./install.sh          # link everything, backing up whatever is already there
#   ./install.sh -n       # dry run: print what would happen, touch nothing
#   ./install.sh -c       # copy instead of symlink (for a machine you only restore once)
#
# Anything replaced is moved to ~/.dotfiles-backup/<timestamp>/ first, so a bad
# run is always undoable.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
DRY=0
MODE=link

while getopts 'nch' opt; do
    case "$opt" in
        n) DRY=1 ;;
        c) MODE=copy ;;
        h) sed -n '2,10p' "$0"; exit 0 ;;
        *) exit 2 ;;
    esac
done

say() { printf '%s\n' "$*"; }
run() { [ "$DRY" -eq 1 ] && { say "  would: $*"; return 0; }; "$@"; }

# place <source-in-repo> <destination>
place() {
    local src="$1" dst="$2"

    [ -e "$src" ] || return 0

    # Already the link we want -- nothing to do.
    if [ "$MODE" = link ] && [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
        say "  ok    ${dst/#$HOME/\~}"
        return 0
    fi

    if [ -e "$dst" ] || [ -L "$dst" ]; then
        say "  backup ${dst/#$HOME/\~}"
        run mkdir -p "$BACKUP/$(dirname "${dst#$HOME/}")"
        run mv "$dst" "$BACKUP/${dst#$HOME/}"
    fi

    run mkdir -p "$(dirname "$dst")"
    if [ "$MODE" = link ]; then
        say "  link  ${dst/#$HOME/\~}"
        run ln -s "$src" "$dst"
    else
        say "  copy  ${dst/#$HOME/\~}"
        run cp -a "$src" "$dst"
    fi
}

[ "$DRY" -eq 1 ] && say ":: dry run -- nothing will be changed"
say ":: installing from $REPO"

say ""
say ":: ~/.config"
for item in "$REPO"/config/*; do
    place "$item" "$HOME/.config/$(basename "$item")"
done

say ""
say ":: ~/.local/bin"
mkdir -p "$HOME/.local/bin"
for item in "$REPO"/local/bin/*; do
    place "$item" "$HOME/.local/bin/$(basename "$item")"
done

say ""
say ":: ~/.local/share"
for item in "$REPO"/local/share/*; do
    place "$item" "$HOME/.local/share/$(basename "$item")"
done

say ""
say ":: home"
place "$REPO/home/zshrc" "$HOME/.zshrc"

say ""
if [ "$DRY" -eq 1 ]; then
    say ":: dry run finished"
else
    [ -d "$BACKUP" ] && say ":: replaced files are in $BACKUP"
    say ":: done -- log out and back in, or run 'hyprctl reload'"
fi
