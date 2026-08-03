#!/usr/bin/env bash
# Prints the number of pending updates as "Arch:<n>, AUR:<n>".
# checkupdates syncs into its own temp db, so this never touches the real
# pacman sync state and is safe to run on a timer.

repo=$(checkupdates 2>/dev/null | wc -l)
aur=$(paru -Qua 2>/dev/null | wc -l)

echo "Arch:$repo, AUR:$aur"
