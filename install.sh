#!/usr/bin/env bash
#
# Symlink this repo's files into place.
#
#   ./install.sh -n       # dry run: print what would happen, touch nothing
#   ./install.sh          # link everything, backing up whatever is already there
#   ./install.sh -c       # copy instead of symlink (for a machine you only restore once)
#   ./install.sh -u       # uninstall: remove our links, restore the newest backup
#
# Always dry-run first. Anything replaced is moved to
# ~/.dotfiles-backup/<timestamp>/, so a bad run is always undoable.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="$HOME/.dotfiles-backup"
BACKUP="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
DRY=0
MODE=link
ACTION=install

while getopts 'ncuh' opt; do
    case "$opt" in
        n) DRY=1 ;;
        c) MODE=copy ;;
        u) ACTION=uninstall ;;
        h) awk 'NR>1 && /^#/ {sub(/^# ?/,""); print; next} NR>1 {exit}' "$0"; exit 0 ;;
        *) exit 2 ;;
    esac
done

say()  { printf '%s\n' "$*"; }
run()  { [ "$DRY" -eq 1 ] && { say "  would: $*"; return 0; }; "$@"; }
tilde() { printf '%s' "${1/#$HOME/\~}"; }

# The colour files matugen generates. They are gitignored -- the repo tracks a
# neutral fallback in defaults/ instead, so a fresh clone comes up with a usable
# theme and `wallpaper` overwrites it on first run. Format: <default>:<live path>
GENERATED=(
    "hypr-colors.lua:$HOME/.config/hypr/colors.lua"
    "hyprlock.conf:$HOME/.config/hypr/hyprlock.conf"
    "quickshell-Colors.qml:$HOME/.config/quickshell/Colors.qml"
    "wlogout-style.css:$HOME/.config/wlogout/style.css"
    "gtk-colors.css:$HOME/.config/gtk-3.0/colors.css"
    "gtk-colors.css:$HOME/.config/gtk-4.0/colors.css"
    "alacritty-colors.toml:$HOME/.config/alacritty/colors.toml"
)

# ---------------------------------------------------------------- install ----

# place <source-in-repo> <destination>
place() {
    local src="$1" dst="$2"

    [ -e "$src" ] || return 0

    if [ "$MODE" = link ] && [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
        say "  ok     $(tilde "$dst")"
        return 0
    fi

    if [ -e "$dst" ] || [ -L "$dst" ]; then
        say "  backup $(tilde "$dst")"
        run mkdir -p "$BACKUP/$(dirname "${dst#$HOME/}")"
        run mv "$dst" "$BACKUP/${dst#$HOME/}"
    fi

    run mkdir -p "$(dirname "$dst")"
    if [ "$MODE" = link ]; then
        say "  link   $(tilde "$dst")"
        run ln -s "$src" "$dst"
    else
        say "  copy   $(tilde "$dst")"
        run cp -a "$src" "$dst"
    fi
}

# Seed a neutral colour file wherever the themed one is missing. Runs after
# linking, so with symlinks this writes through into the repo (where the path is
# gitignored) and with -c it writes into ~/.config -- one code path, both modes.
seed_generated() {
    local entry src dst seeded=0
    for entry in "${GENERATED[@]}"; do
        src="$REPO/defaults/${entry%%:*}"
        dst="${entry#*:}"
        [ -e "$src" ] || continue
        if [ -e "$dst" ]; then
            say "  themed $(tilde "$dst")"
        else
            say "  seed   $(tilde "$dst")"
            run mkdir -p "$(dirname "$dst")"
            run cp "$src" "$dst"
            seeded=1
        fi
    done
    [ "$seeded" -eq 1 ] && say "  (run 'wallpaper' to replace these with real colours)"
    return 0
}

do_install() {
    [ "$DRY" -eq 1 ] && say ":: dry run -- nothing will be changed"
    say ":: installing from $REPO"

    say ""
    say ":: ~/.config"
    for item in "$REPO"/config/*; do
        place "$item" "$HOME/.config/$(basename "$item")"
    done

    say ""
    say ":: ~/.local/bin"
    [ "$DRY" -eq 1 ] || mkdir -p "$HOME/.local/bin"
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
    say ":: colours"
    seed_generated

    say ""
    if [ "$DRY" -eq 1 ]; then
        say ":: dry run finished -- re-run without -n to apply"
    else
        [ -d "$BACKUP" ] && say ":: replaced files are in $BACKUP"
        say ":: done -- log out and back in, or run 'hyprctl reload'"
    fi
}

# -------------------------------------------------------------- uninstall ----

# Only ever removes symlinks that resolve into this repo. Real files and
# directories, and links pointing anywhere else, are left alone.
unlink_ours() {
    local dst="$1" target
    [ -L "$dst" ] || return 0
    target="$(readlink -f "$dst" || true)"
    case "$target" in
        "$REPO"/*)
            say "  unlink $(tilde "$dst")"
            run rm "$dst"
            ;;
        *)
            say "  skip   $(tilde "$dst") (not ours)"
            ;;
    esac
}

do_uninstall() {
    [ "$DRY" -eq 1 ] && say ":: dry run -- nothing will be changed"
    say ":: uninstalling links into $REPO"
    say ""

    for item in "$REPO"/config/*; do
        unlink_ours "$HOME/.config/$(basename "$item")"
    done
    for item in "$REPO"/local/bin/*; do
        unlink_ours "$HOME/.local/bin/$(basename "$item")"
    done
    for item in "$REPO"/local/share/*; do
        unlink_ours "$HOME/.local/share/$(basename "$item")"
    done
    unlink_ours "$HOME/.zshrc"

    # Restore the most recent backup over the gaps we just made.
    local newest
    newest="$(find "$BACKUP_ROOT" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort | tail -1)"

    say ""
    if [ -z "$newest" ]; then
        say ":: no backup found in $BACKUP_ROOT -- nothing to restore"
        say ":: (your pre-install config may simply never have existed)"
        return 0
    fi

    say ":: restoring from $newest"
    local f rel dst
    while IFS= read -r f; do
        rel="${f#$newest/}"
        dst="$HOME/$rel"
        if [ -e "$dst" ] || [ -L "$dst" ]; then
            say "  exists $(tilde "$dst") -- left in the backup, not restored"
            continue
        fi
        say "  restore $(tilde "$dst")"
        run mkdir -p "$(dirname "$dst")"
        run cp -a "$f" "$dst"
    done < <(find "$newest" -mindepth 1 -maxdepth 3 \( -type f -o -type d \) -prune 2>/dev/null | sort)

    say ""
    if [ "$DRY" -eq 1 ]; then
        say ":: dry run finished -- re-run without -n to apply"
    else
        say ":: done. The backup is kept at $newest -- delete it when you're happy."
    fi
}

case "$ACTION" in
    install)   do_install ;;
    uninstall) do_uninstall ;;
esac
