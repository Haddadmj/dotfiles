#!/usr/bin/env bash
# Change the file icon or cursor theme, live and kept across logins.
#   appearance.sh pick icons|cursor          choose an installed theme (wofi)
#   appearance.sh next icons|cursor          switch to the next installed theme
#   appearance.sh set  icons|cursor <name>   use a specific theme
#   appearance.sh size bigger|smaller|<px>   change the cursor size (16-96)
set -euo pipefail

CURSOR_STATE="$HOME/.config/hypr/cursor-theme"   # read by modules/env.lua at startup
SIZE_STATE="$HOME/.config/hypr/cursor-size"      # same

list_themes() {
    local d
    for d in "$HOME/.local/share/icons"/*/ "$HOME/.icons"/*/ /usr/share/icons/*/; do
        [[ -d $d ]] || continue
        if [[ $1 == cursor ]]; then
            [[ -d $d/cursors || -f $d/manifest.hl || -f $d/manifest.toml ]] || continue
        else
            # cursor-only themes have no Directories=; Hidden= marks base themes like hicolor
            grep -q '^Directories=' "$d/index.theme" 2>/dev/null || continue
            grep -q '^Hidden=true' "$d/index.theme" && continue
        fi
        basename "$d"
    done | sort -u
}

current() {
    if [[ $1 == cursor ]]; then
        cat "$CURSOR_STATE" 2>/dev/null || true
    else
        gsettings get org.gnome.desktop.interface icon-theme | tr -d "'"
    fi
}

cursor_size() { cat "$SIZE_STATE" 2>/dev/null || echo 24; }

# same value for everything that reads GTK settings: GTK3/4, GTK2 and X11 apps
gtk_files() { # <gtk key> <xsettingsd key> <value> <quote for string values>
    local ini
    for ini in "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"; do
        [[ -f $ini ]] && sed -i "s/^$1=.*/$1=$3/" "$ini"
    done
    [[ -f $HOME/.gtkrc-2.0 ]] && sed -i "s/^$1=.*/$1=$4$3$4/" "$HOME/.gtkrc-2.0"
    [[ -f $HOME/.config/xsettingsd/xsettingsd.conf ]] && sed -i "s|^$2 .*|$2 $4$3$4|" "$HOME/.config/xsettingsd/xsettingsd.conf"
    pkill -HUP -x xsettingsd || true
}

apply() {
    local kind=$1 name=$2
    list_themes "$kind" | grep -qxF "$name" || { notify-send "appearance.sh" "Theme not installed: $name"; exit 1; }
    if [[ $kind == cursor ]]; then
        printf '%s\n' "$name" > "$CURSOR_STATE"
        hyprctl setcursor "$name" "$(cursor_size)" >/dev/null
        gsettings set org.gnome.desktop.interface cursor-theme "$name"
        kwriteconfig6 --file kcminputrc --group Mouse --key cursorTheme "$name"
        gtk_files gtk-cursor-theme-name Gtk/CursorThemeName "$name" '"'
    else
        gsettings set org.gnome.desktop.interface icon-theme "$name"
        kwriteconfig6 --file kdeglobals --group Icons --key Theme "$name"
        gtk_files gtk-icon-theme-name Net/IconThemeName "$name" '"'
        # tells running KDE/Qt apps (Dolphin) to reload their icons
        dbus-send --session --type=signal /KIconLoader org.kde.KIconLoader.iconChanged int32:0 || true
    fi
    notify-send -t 1500 "$([[ $kind == cursor ]] && echo Cursor || echo Icon) theme" "$name" || true
}

set_size() {
    local px theme
    case "$1" in
        bigger)  px=$(( $(cursor_size) + 4 )) ;;
        smaller) px=$(( $(cursor_size) - 4 )) ;;
        *)       [[ $1 =~ ^[0-9]+$ ]] || { sed -n '2,6p' "$0"; exit 1; }; px=$1 ;;
    esac
    (( px < 16 )) && px=16
    (( px > 96 )) && px=96
    printf '%s\n' "$px" > "$SIZE_STATE"
    theme=$(current cursor)
    hyprctl setcursor "${theme:-default}" "$px" >/dev/null
    gsettings set org.gnome.desktop.interface cursor-size "$px"
    kwriteconfig6 --file kcminputrc --group Mouse --key cursorSize "$px"
    gtk_files gtk-cursor-theme-size Gtk/CursorThemeSize "$px" ''
    notify-send -t 1500 "Cursor size" "$px px" || true
}

if [[ ${1:-} == size ]]; then
    set_size "${2:-}"
    exit 0
fi

kind=${2:-}
[[ $kind == icons || $kind == cursor ]] || { sed -n '2,6p' "$0"; exit 1; }

case "${1:-}" in
    pick)
        name=$(list_themes "$kind" | wofi --dmenu --prompt "$kind theme") || exit 0
        apply "$kind" "$name" ;;
    next)
        mapfile -t themes < <(list_themes "$kind")
        cur=$(current "$kind")
        name=${themes[0]}
        for i in "${!themes[@]}"; do
            [[ ${themes[i]} == "$cur" ]] && name=${themes[(i + 1) % ${#themes[@]}]}
        done
        apply "$kind" "$name" ;;
    set)
        apply "$kind" "${3:?usage: appearance.sh set icons|cursor <name>}" ;;
    *) sed -n '2,6p' "$0"; exit 1 ;;
esac
