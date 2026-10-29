#!/usr/bin/env bash
# Copy the live config listed in files.txt into this repo (home/), plus the current wallpaper.
# Run it whenever you've changed something you want to keep, then commit.
set -euo pipefail
DOT=$(cd "$(dirname "$0")" && pwd)

rm -rf "$DOT/home"; mkdir -p "$DOT/home"
grep -vE '^\s*(#|$)' "$DOT/files.txt" | while read -r _group path; do
    if [[ -e $HOME/$path ]]; then
        rsync -aR --exclude '*.bak*' --exclude '*.pre-restore-*' --exclude 'wallhaven/apikey' "$HOME/./$path" "$DOT/home/"
    else
        echo "skip (missing): ~/$path"
    fi
done

# current wallpaper only — the whole folder is too big for git
wall=$(sed -n 1p "$HOME/.cache/theme-state" 2>/dev/null || true)
if [[ -f $wall ]]; then
    mkdir -p "$DOT/home/Pictures/Wallpapers"
    cp "$wall" "$DOT/home/Pictures/Wallpapers/"
fi

# make paths user-independent; install.sh turns __HOME__ back into the new $HOME
grep -rlIF "$HOME" "$DOT/home" | xargs -r sed -i "s|$HOME|__HOME__|g"

pacman -Qqe > "$DOT/packages/installed-snapshot.txt"   # reference only, not installed

echo "Snapshot done: $(find "$DOT/home" -type f | wc -l) files."
if git -C "$DOT" rev-parse >/dev/null 2>&1; then
    git -C "$DOT" status --short | head -20
    echo "Save it:  git -C $DOT add -A && git -C $DOT commit -m 'snapshot' && git -C $DOT push"
fi
