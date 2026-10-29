#!/usr/bin/env bash
# Change wallpaper and regenerate the color scheme from it (matugen).
#   theme.sh pick          choose a wallpaper (Quickshell grid, wofi fallback)
#   theme.sh random        random wallpaper from $WALL_DIR
#   theme.sh set <file>    use a specific image
#   theme.sh toggle-mode   switch light/dark using the current wallpaper
set -euo pipefail

WALL_DIR="${WALL_DIR:-$HOME/Pictures/Wallpapers}"
STATE="$HOME/.cache/theme-state"   # line 1: wallpaper, line 2: mode
HYPR="$HOME/.config/hypr"
mkdir -p "$(dirname "$STATE")" "$HOME/.local/share/color-schemes"

cur_wall=""; mode="dark"
[[ -f $STATE ]] && { cur_wall=$(sed -n 1p "$STATE"); mode=$(sed -n 2p "$STATE"); }
mode=${mode:-dark}

# top level plus the sfw/sketchy/nsfw folders made by wallhaven-dl
list_walls() { find "$WALL_DIR" -maxdepth 2 -path '*/.colors' -prune -o -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) -print | sort; }

case "${1:-pick}" in
    pick)
        # Quickshell grid picker if the shell is running (it calls `theme.sh set`), else wofi
        qs ipc call wallpapers toggle >/dev/null 2>&1 && exit 0
        # cached thumbnails so wofi can show a preview of each wallpaper
        thumbs="$HOME/.cache/wallthumbs"; mkdir -p "$thumbs"
        sel=$(list_walls | while IFS= read -r f; do
                t="$thumbs/$(printf '%s' "$f" | md5sum | cut -c1-32).jpg"
                [[ $t -nt $f ]] || vipsthumbnail "$f" -s 480x270 -m centre --path "$t[Q=85]" 2>/dev/null
                printf 'img:%s:text:%s\n' "$t" "${f#"$WALL_DIR"/}"
            done | wofi --dmenu --allow-images --parse-search --prompt "Wallpaper" \
                        --columns 3 --width 1100 --height 700 \
                        -D image_size=300 -D hide_scroll=true) || exit 0
        wall="$WALL_DIR/${sel##*:text:}" ;;
    random)
        wall=$(list_walls | grep -vxF "$cur_wall" | shuf -n1) ;;
    set)
        wall=$(realpath "${2:?usage: theme.sh set <image>}") ;;
    toggle-mode)
        [[ $mode == dark ]] && mode=light || mode=dark
        wall=${cur_wall:-$(list_walls | head -n1)} ;;
    *) sed -n '2,7p' "$0"; exit 1 ;;
esac
[[ -f $wall ]] || { notify-send "theme.sh" "No wallpaper found: $wall"; exit 1; }
printf '%s\n%s\n' "$wall" "$mode" > "$STATE"

# 1. wallpaper (hyprpaper also reads hyprpaper.conf at startup, so persist it)
cat > "$HYPR/hyprpaper.conf" <<CONF
wallpaper {
    monitor =
    path = $wall
    fit_mode = cover
}

splash = false
CONF
hyprctl hyprpaper wallpaper ",$wall,cover" >/dev/null || true

# 2. colors
matugen -q -c "$HYPR/matugen/config.toml" -m "$mode" --prefer saturation image "$wall"

# 3. reload everything that uses them
hyprctl reload >/dev/null
pkill -SIGUSR2 waybar || true          # waybar reloads its style (quickshell watches colors.json itself)
pkill -SIGUSR1 kitty  || true          # kitty reloads its config
pkill -SIGUSR2 ghostty || true         # ghostty reloads its config

# KDE/Qt (Dolphin): plasma-apply-colorscheme ignores re-applying the same name, so alternate two names
cur_kde=$(kreadconfig6 --group General --key ColorScheme 2>/dev/null || true)
[[ $cur_kde == MatugenA ]] && name=MatugenB || name=MatugenA
sed "s/^ColorScheme=.*/ColorScheme=$name/; s/^Name=.*/Name=$name/" \
    "$HOME/.cache/matugen/Matugen.colors" > "$HOME/.local/share/color-schemes/$name.colors"
if command -v plasma-apply-colorscheme >/dev/null; then
    plasma-apply-colorscheme "$name" >/dev/null 2>&1 || true
else
    # no Plasma (qt6ct-kde setup): merge the scheme into kdeglobals ourselves, and give qt6ct a fixed path
    cp "$HOME/.cache/matugen/Matugen.colors" "$HOME/.local/share/color-schemes/Matugen.colors"
    awk -F= '/^\[.*\]$/ { g = substr($0, 2, length($0) - 2); next }
             g ~ /^Colors:|^WM$|^General$/ && NF >= 2 { k = $1; sub(/^[^=]*=/, ""); printf "%s\t%s\t%s\n", g, k, $0 }' \
        "$HOME/.cache/matugen/Matugen.colors" |
    while IFS=$'\t' read -r grp key val; do
        args=(); IFS=']' read -ra parts <<<"${grp//\]\[/]}"   # nested groups like [Colors:Button][Inactive]
        for p in "${parts[@]}"; do args+=(--group "$p"); done
        kwriteconfig6 --file kdeglobals "${args[@]}" --key "$key" "$val"
    done
    kwriteconfig6 --file kdeglobals --group General --key ColorScheme Matugen
fi

# GTK apps
gsettings set org.gnome.desktop.interface color-scheme "prefer-$mode"
gsettings set org.gnome.desktop.interface gtk-theme "$([[ $mode == dark ]] && echo Breeze-Dark || echo Breeze)"

notify-send -i "$wall" "Theme updated" "$(basename "$wall") · $mode" || true
