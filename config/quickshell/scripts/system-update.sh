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
BEFORE=$(mktemp)
AFTER=$(mktemp)
trap 'rm -f "$TMP" "$BEFORE" "$AFTER"' EXIT

# Snapshot of "name version" for every installed package. Diffing this against
# the same list afterwards reports what actually changed, including the pulled
# in dependencies that never show up in the pending-update count.
pacman -Q >"$BEFORE" 2>/dev/null

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
status=$?

pacman -Q >"$AFTER" 2>/dev/null

echo
gawk '
    NR == FNR { old[$1] = $2; next }
    {
        cur[$1] = $2
        if (!($1 in old))       added[$1] = $2
        else if (old[$1] != $2) upgraded[$1] = old[$1] " -> " $2
    }
    END {
        for (p in old)
            if (!(p in cur)) removed[p] = old[p]

        report("Upgraded", upgraded)
        report("Installed", added)
        report("Removed", removed)

        if (!printed) print ":: Nothing changed — the system was already up to date."
    }

    function report(title, list,    names, n, i, w) {
        n = asorti(list, names)
        if (n == 0) return

        w = 0
        for (i = 1; i <= n; i++)
            if (length(names[i]) > w) w = length(names[i])

        if (printed) print ""
        printf ":: %s (%d):\n", title, n
        for (i = 1; i <= n; i++)
            printf "   %-*s  %s\n", w, names[i], list[names[i]]
        printed = 1
    }
' "$BEFORE" "$AFTER"

echo
# The launcher closes the terminal the moment this exits, so hold the window
# open long enough to actually read the list. Failures keep their own prompt.
if [ "$status" -eq 0 ]; then
    read -r -t 60 -p ":: Press Enter to close (closes on its own in 60s)... " _ || true
    echo
fi

exit "$status"
