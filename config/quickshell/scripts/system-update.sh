#!/usr/bin/env bash
# Refresh the mirrorlist to recent + fastest mirrors, then do a full
# system upgrade from the official repos and the AUR.
set -uo pipefail

MIRRORLIST=/etc/pacman.d/mirrorlist
BACKUP=/etc/pacman.d/mirrorlist.bak

echo ":: Refreshing mirrorlist (recently synced, ranked by speed)..."
# rate-mirrors refuses to run as root, so it writes here unprivileged and
# only the final install step goes through sudo.
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

# --protocol https              only https mirrors
# --max-mirrors-to-output 20    keep the list short, like reflector's --number
# --disable-untested-fallback   fail loudly instead of writing untested mirrors
# --disable-comments-in-file    keep the mirrorlist to bare Server = lines
# --max-delay 43200             only mirrors synced in the last 12h
if rate-mirrors \
    --protocol https \
    --max-mirrors-to-output 20 \
    --disable-untested-fallback \
    --disable-comments-in-file \
    --save "$TMP" \
    arch --max-delay 43200
then
    if sudo cp "$MIRRORLIST" "$BACKUP" &&
        sudo install -m 644 "$TMP" "$MIRRORLIST"
    then
        echo ":: Mirrorlist updated (previous list kept at $BACKUP)."
    else
        echo "!! Could not install new mirrorlist — keeping the current one."
    fi
else
    echo "!! rate-mirrors failed — keeping the current mirrorlist."
fi

echo
echo ":: Upgrading system (repos + AUR)..."
# --noconfirm   answer the pacman/paru prompts automatically
# --skipreview  don't stop to show AUR PKGBUILD diffs before building
paru -Syu --noconfirm --skipreview
