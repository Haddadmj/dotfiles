#!/usr/bin/env bash
# Hyprland dotfiles installer for Arch Linux.
#   ./install.sh                 ask everything (no groups pre-ticked; app/look defaults = the original setup)
#   ./install.sh -c my.conf      take answers from a preset file, ask only what it leaves out
#   ./install.sh -y              accept defaults for anything not in the preset (no questions;
#                                groups: none, plus nvidia if an NVIDIA GPU is found)
#   ./install.sh -d              dotfiles only: re-apply config + choices, skip packages/services
# Your answers are saved to last-install.conf, so `./install.sh -c last-install.conf -y` repeats a run.
set -euo pipefail
DOT=$(cd "$(dirname "$0")" && pwd)
TS=$(date +%Y%m%d-%H%M%S)
GROUP_LIST=(fonts nvidia kde-apps shell apps gaming dev virt)   # optional groups; core is always installed

PRESET=""; YES=0; ONLY_DOTS=0
while getopts "c:ydh" o; do
    case $o in
        c) PRESET=$OPTARG ;;
        y) YES=1 ;;
        d) ONLY_DOTS=1 ;;
        *) sed -n '2,8p' "$0"; exit 0 ;;
    esac
done
[[ -n $PRESET ]] && source "$PRESET"

[[ $EUID -eq 0 ]] && { echo "Run as your normal user, not root (sudo is used when needed)."; exit 1; }
command -v pacman >/dev/null || { echo "This installer is for Arch Linux."; exit 1; }

# ── sudo once ──────────────────────────────────────────────────────────────────
# ask for the password a single time, then keep the sudo timestamp fresh until the script exits
if (( ! ONLY_DOTS )); then
    echo "Your password is needed once; sudo stays unlocked until the installer finishes."
    sudo -v
    ( while kill -0 $$ 2>/dev/null; do sudo -n true; sleep 50; done ) 2>/dev/null &
    SUDO_KEEPALIVE=$!
    trap 'kill $SUDO_KEEPALIVE 2>/dev/null' EXIT
fi

# ── helpers ────────────────────────────────────────────────────────────────────
say()  { gum style --foreground 212 --bold "==> $*"; }
info() { gum style --faint "    $*"; }
# ask VAR "question" default opt1 opt2 …   (no options = free text)
ask() {
    local var=$1 q=$2 def=$3; shift 3
    [[ -n ${!var:-} ]] && return
    if (( YES )); then printf -v "$var" '%s' "$def"; return; fi
    local a
    if (( $# )); then a=$(gum choose --header "$q" --selected "$def" "$@")
    else a=$(gum input --header "$q" --value "$def"); printf -v "$var" '%s' "$a"; return; fi
    printf -v "$var" '%s' "${a:-$def}"
}
has() { [[ " $1 " == *" $2 "* ]]; }
pkgfile_() { echo "$DOT/packages/$1.txt"; }
# package names of a group (strips comments)
pkgs()  { sed 's/#.*//' "$(pkgfile_ "$1")" | tr -s ' \t' '\n' | grep -v '^$'; }
# "name — description" lines for the picker
items() { grep -vE '^\s*(#|$)' "$(pkgfile_ "$1")" | sed -E 's/^(\S+)\s*#\s*(.*)$/\1 — \2/'; }
# menu label: group, its title comment, and a few example apps
label() {
    local title sample
    title=$(sed -n '1s/^#\s*//p' "$(pkgfile_ "$1")" | sed 's/ (.*//; s/ — .*//')
    sample=$(pkgs "$1" | head -4 | paste -sd' ')
    printf '%-9s %s  ·  %s…' "$1" "$title" "$sample"
}

# ── bootstrap: gum (menus) + paru (AUR) ─────────────────────────────────────────
if (( ONLY_DOTS )); then command -v gum >/dev/null || sudo pacman -S --needed --noconfirm gum
else sudo pacman -S --needed --noconfirm git base-devel gum pciutils; fi
if (( ! ONLY_DOTS )) && ! command -v paru >/dev/null; then
    echo "==> Installing paru (AUR helper)"
    tmp=$(mktemp -d)
    git clone --depth 1 https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin"
    (cd "$tmp/paru-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
fi

gum style --border rounded --padding "1 4" --border-foreground 212 \
    "Hyprland dotfiles" "Quickshell · matugen · Lua config"

# ── hardware detection ─────────────────────────────────────────────────────────
gpus=$(lspci -D | grep -Ei 'vga|3d|display' || true)
nv_addr=$(grep -i nvidia <<<"$gpus" | head -1 | cut -d' ' -f1 || true)
ig_line=$(grep -vi nvidia <<<"$gpus" | head -1 || true)
ig_addr=${ig_line%% *}
ig_name=igpu; grep -qi amd <<<"$ig_line" && ig_name=amd-igpu; grep -qi intel <<<"$ig_line" && ig_name=intel-igpu
def_groups=""                                   # nothing pre-ticked in the menu
[[ -n $nv_addr ]] && yes_groups="nvidia" || yes_groups=""   # -y without a preset still gets GPU drivers
def_hybrid=no; [[ -n $nv_addr && -n $ig_addr ]] && def_hybrid=yes

# ── questions ──────────────────────────────────────────────────────────────────
say "What to install"
info "core (always): $(pkgs core | wc -l) packages — Hyprland, Quickshell, matugen, portals, audio, network, Bluetooth, fonts"
[[ -n $nv_addr ]] && info "NVIDIA GPU detected — tick the nvidia group to get the drivers"
if [[ -z ${PKG_GROUPS:-} ]]; then
    if (( YES )); then PKG_GROUPS=$yes_groups
    else
        labels=(); selected=()
        for g in "${GROUP_LIST[@]}"; do
            labels+=("$(label "$g")")
            has "$def_groups" "$g" && selected+=("$(label "$g")")
        done
        sel_csv=$(IFS=,; echo "${selected[*]}")
        PKG_GROUPS=$(gum choose --no-limit --height 12 --header "Package groups — x = tick/untick, ctrl+a = all, enter = next (you pick apps inside each group next)" \
                        --selected "$sel_csv" "${labels[@]}" | awk '{print $1}' | tr '\n' ' ')
    fi
fi
PKG_GROUPS="core ${PKG_GROUPS//core/}"

# pick individual apps inside each chosen group (PICK_<group> in a preset skips this)
for g in ${PKG_GROUPS}; do
    [[ $g == core ]] && continue
    var="PICK_${g//-/_}"
    [[ -n ${!var:-} ]] && continue
    if (( YES )); then printf -v "$var" '%s' "$(pkgs "$g" | tr '\n' ' ')"; continue; fi
    printf -v "$var" '%s' "$(items "$g" | gum choose --no-limit --height 20 --selected '*' \
        --header "$(label "$g" | sed 's/  ·.*//') — all ticked; x = untick, enter = next" | awk '{print $1}' | tr '\n' ' ')"
done

say "Default apps"
ask TERMINAL_APP "Terminal"     ghostty ghostty kitty alacritty foot
ask BROWSER      "Browser"      brave-origin-nightly brave-origin-nightly brave firefox chromium zen-browser
ask FILE_MANAGER "File manager" dolphin dolphin nautilus thunar nemo
ask EDITOR_APP   "Editor"       code code kate zed gnome-text-editor

say "Keyboard"
ask MAIN_MOD   "Main modifier key" SUPER SUPER ALT
ask KB_LAYOUT  "Keyboard layouts (comma separated, e.g. us,ara or us,de)" "us,ara"
ask KB_OPTIONS "Layout switch option (empty = none)" "grp:caps_toggle"

say "Look"
ask THEME_MODE "Color scheme (generated from the wallpaper)" dark dark light
ask GAPS_IN    "Gap between windows (px)" 5
ask GAPS_OUT   "Gap to screen edge (px)" 20
ask BORDER     "Border width (px)" 2
ask ROUNDING   "Corner rounding (px)" 10
# numbers only, otherwise fall back to the default
for v in GAPS_IN:5 GAPS_OUT:20 BORDER:2 ROUNDING:10; do
    n=${v%%:*}; [[ ${!n} =~ ^[0-9]+$ ]] || printf -v "$n" '%s' "${v#*:}"
done
[[ -n $KB_LAYOUT ]] || KB_LAYOUT=us

say "System"
[[ $def_hybrid == yes ]] && info "Hybrid graphics found: NVIDIA $nv_addr + $ig_name $ig_addr"
ask HYBRID_GPU    "Render Hyprland on the NVIDIA GPU (hybrid laptop/desktop udev rule)?" "$def_hybrid" yes no
ask LOGIN_MANAGER "Login screen — sddm: graphical (adds Xorg) · ly: lightweight terminal UI · plasma-login-manager: KDE's, pulls in Plasma · none: auto-start on TTY1" \
    sddm sddm ly plasma-login-manager none
ask QT_THEME      "Qt/KDE app theming (Dolphin etc.) — qt6ct-kde: no Plasma needed · plasma-integration: KDE's own, pulls in Plasma" \
    qt6ct-kde qt6ct-kde plasma-integration
ask MULTILIB      "Enable [multilib] (32-bit libs; needed by nvidia/gaming)?" yes yes no
ask ZSH_SETUP     "Set up zsh + oh-my-zsh + powerlevel10k as your shell?" "$(has "$PKG_GROUPS" shell && echo yes || echo no)" yes no

# remember answers
{
    for v in PKG_GROUPS TERMINAL_APP BROWSER FILE_MANAGER EDITOR_APP MAIN_MOD KB_LAYOUT KB_OPTIONS THEME_MODE \
             GAPS_IN GAPS_OUT BORDER ROUNDING HYBRID_GPU LOGIN_MANAGER QT_THEME MULTILIB ZSH_SETUP; do
        printf '%s="%s"\n' "$v" "${!v}"
    done
    for g in $PKG_GROUPS; do [[ $g == core ]] || { v="PICK_${g//-/_}"; printf '%s="%s"\n' "$v" "${!v% }"; }; done
} > "$DOT/last-install.conf"
gum style --border normal --padding "0 2" "$(cat "$DOT/last-install.conf")"

# map app choices to package names / commands
declare -A PKG=([brave-origin-nightly]=brave-origin-nightly-bin [brave]=brave-bin [zen-browser]=zen-browser-bin
                [code]=code [zed]=zed)
declare -A CMD=([zed]=zeditor)   # apps whose command differs from their name

extra=()
for app in "$TERMINAL_APP" "$BROWSER" "$FILE_MANAGER" "$EDITOR_APP"; do extra+=("${PKG[$app]:-$app}"); done
[[ $LOGIN_MANAGER != none ]] && extra+=("$LOGIN_MANAGER")
extra+=("$QT_THEME")
[[ $QT_THEME == qt6ct-kde ]] && extra+=(archlinux-xdg-menu)   # "Open with" menus without Plasma
[[ $ZSH_SETUP == yes ]] && extra+=(zsh)

mapfile -t list < <( {
    pkgs core
    for g in $PKG_GROUPS; do [[ $g == core ]] || { v="PICK_${g//-/_}"; tr ' ' '\n' <<<"${!v}"; }; done
    printf '%s\n' "${extra[@]}"
} | grep -v '^$' | sort -u)
[[ $MULTILIB == yes ]] || mapfile -t list < <(printf '%s\n' "${list[@]}" | grep -v '^lib32-')
if (( ! ONLY_DOTS )); then
    say "These ${#list[@]} packages will be installed (repo + AUR, already-installed ones are skipped):"
    printf '%s\n' "${list[@]}" | column -c "$(tput cols 2>/dev/null || echo 100)" | sed 's/^/    /'
fi
(( YES )) || gum confirm "Install with these settings?" || exit 0

# ── packages ───────────────────────────────────────────────────────────────────
if (( ! ONLY_DOTS )); then
say "Packages"
if [[ $MULTILIB == yes ]] && ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
fi
sudo pacman -Syu --noconfirm

# install in one go; on failure retry one by one so a single renamed package doesn't stop everything
# (--sudoloop keeps paru's own sudo alive through long AUR builds)
if ! paru -S --needed --noconfirm --sudoloop "${list[@]}"; then
    failed=()
    for p in "${list[@]}"; do paru -S --needed --noconfirm --sudoloop "$p" || failed+=("$p"); done
    (( ${#failed[@]} )) && gum style --foreground 196 "Could not install: ${failed[*]}"
fi
fi

# ── dotfiles ───────────────────────────────────────────────────────────────────
say "Dotfiles"
stage=$(mktemp -d)
cp -a "$DOT/home/." "$stage/"
grep -rlIF __HOME__ "$stage" | xargs -r sed -i "s|__HOME__|$HOME|g"

# drop file groups that weren't picked
grep -vE '^\s*(#|$)' "$DOT/files.txt" | while read -r group path; do
    if [[ $group == shell && $ZSH_SETUP != yes ]] || { [[ $group != core && $group != shell ]] && ! has "$PKG_GROUPS" "$group"; }; then
        rm -rf "${stage:?}/$path"
    fi
done

H=$stage/.config/hypr
cat > "$H/modules/programs.lua" <<EOF
-- Programs used across modules. Returned as a table: local P = require("modules.programs")
return {
    terminal    = "$TERMINAL_APP",
    fileManager = "$FILE_MANAGER",
    menu        = "hyprlauncher",
    browser     = "$BROWSER",
    editor      = "${CMD[$EDITOR_APP]:-$EDITOR_APP}",
    mainMod     = "$MAIN_MOD",
}
EOF
sed -i -E "s|^(hl.env\(\"TERMINAL\", )\"[^\"]*\"|\1\"$TERMINAL_APP\"|" "$H/modules/env.lua"
sed -i -E "s|^(\s*kb_layout\s*=\s*)\"[^\"]*\"|\1\"$KB_LAYOUT\"|; s|^(\s*kb_options\s*=\s*)\"[^\"]*\"|\1\"$KB_OPTIONS\"|" "$H/modules/input.lua"
sed -i -E "s|^(\s*gaps_in\s*=\s*)[0-9]+|\1$GAPS_IN|; s|^(\s*gaps_out\s*=\s*)[0-9]+|\1$GAPS_OUT|;
           s|^(\s*border_size\s*=\s*)[0-9]+|\1$BORDER|; s|^(\s*rounding\s*=\s*)[0-9]+|\1$ROUNDING|" "$H/modules/look.lua"
[[ -f $stage/.cache/theme-state ]] && sed -i "2s/.*/$THEME_MODE/" "$stage/.cache/theme-state"

if [[ $HYBRID_GPU == yes && -n $nv_addr && -n $ig_addr ]]; then
    sed -i -E "s|^(-- )?(hl.env\(\"AQ_DRM_DEVICES\", )\"[^\"]*\"|\2\"/dev/dri/nvidia-gpu:/dev/dri/$ig_name\"|" "$H/modules/env.lua"
    printf 'KERNEL=="card*", KERNELS=="%s", SUBSYSTEM=="drm", SYMLINK+="dri/nvidia-gpu"\nKERNEL=="card*", KERNELS=="%s", SUBSYSTEM=="drm", SYMLINK+="dri/%s"\n' \
        "$nv_addr" "$ig_addr" "$ig_name" | sudo tee /etc/udev/rules.d/99-gpu-names.rules >/dev/null
    info "wrote /etc/udev/rules.d/99-gpu-names.rules"
else
    sed -i -E 's|^(hl.env\("AQ_DRM_DEVICES")|-- \1|' "$H/modules/env.lua"
fi
if [[ $QT_THEME == qt6ct-kde ]]; then
    sed -i -E 's|^(hl.env\("QT_QPA_PLATFORMTHEME", )"[^"]*"|\1"qt6ct"|; s|^(hl.env\("XDG_MENU_PREFIX", )"[^"]*"|\1"arch-"|' "$H/modules/env.lua"
    cs=$stage/.local/share/color-schemes
    cur=$(sed -n 's/^ColorScheme=//p' "$stage/.config/kdeglobals" 2>/dev/null | head -1)
    [[ -f $cs/Matugen.colors || ! -f $cs/$cur.colors ]] || cp "$cs/$cur.colors" "$cs/Matugen.colors"
    mkdir -p "$stage/.config/qt6ct"
    cat > "$stage/.config/qt6ct/qt6ct.conf" <<EOF
[Appearance]
color_scheme_path=$HOME/.local/share/color-schemes/Matugen.colors
custom_palette=true
icon_theme=$([[ $THEME_MODE == dark ]] && echo breeze-dark || echo breeze)
standard_dialogs=default
style=Breeze
EOF
fi
if ! has "$PKG_GROUPS" nvidia; then   # NVIDIA-only env vars break VA-API on other GPUs
    sed -i -E 's/^(hl.env\("(LIBVA_DRIVER_NAME|__GLX_VENDOR_LIBRARY_NAME|NVD_BACKEND)")/-- \1/' "$H/modules/env.lua"
fi

# back up whatever is about to be replaced, then copy
backup=$HOME/.dotfiles-backup/$TS
grep -vE '^\s*(#|$)' "$DOT/files.txt" | while read -r _group p; do
    if [[ -e $stage/$p && -e $HOME/$p ]]; then mkdir -p "$backup/$(dirname "$p")"; cp -a "$HOME/$p" "$backup/$p"; fi
done
rsync -a "$stage/" "$HOME/"
rm -rf "$stage"
[[ -d $backup ]] && info "old files backed up to $backup"

# colors in the repo were generated in the snapshot's mode; regenerate if a different one was picked
wall=$(sed -n 1p "$HOME/.cache/theme-state" 2>/dev/null || true)
if [[ $THEME_MODE != "$(sed -n 2p "$DOT/home/.cache/theme-state" 2>/dev/null)" && -f $wall ]] && command -v matugen >/dev/null; then
    "$HOME/.config/hypr/scripts/theme.sh" set "$wall" >/dev/null 2>&1 || true
    info "regenerated $THEME_MODE colors from $(basename "$wall")"
fi

(( ONLY_DOTS )) && { say "Dotfiles applied. Reload with: hyprctl reload"; exit 0; }

# ── shell ──────────────────────────────────────────────────────────────────────
if [[ $ZSH_SETUP == yes ]]; then
    say "zsh"
    [[ -d $HOME/.oh-my-zsh ]] || RUNZSH=no KEEP_ZSHRC=yes CHSH=no \
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    C=$HOME/.oh-my-zsh/custom
    while read -r dir url; do
        [[ -d $C/$dir ]] || git clone --depth 1 "$url" "$C/$dir"
    done <<'EOF'
themes/powerlevel10k             https://github.com/romkatv/powerlevel10k
plugins/fzf-tab                  https://github.com/Aloxaf/fzf-tab
plugins/you-should-use           https://github.com/MichaelAquilina/zsh-you-should-use
plugins/zsh-autosuggestions      https://github.com/zsh-users/zsh-autosuggestions
plugins/zsh-completions          https://github.com/zsh-users/zsh-completions
plugins/zsh-syntax-highlighting  https://github.com/zsh-users/zsh-syntax-highlighting
EOF
    # via sudo so it doesn't ask for the password again (plain chsh always prompts)
    [[ $(getent passwd "$USER" | cut -d: -f7) == */zsh ]] || sudo chsh -s /usr/bin/zsh "$USER"
    sudo pkgfile --update >/dev/null 2>&1 || true   # for the command-not-found plugin
fi

# ── services ───────────────────────────────────────────────────────────────────
say "Services"
sudo systemctl enable NetworkManager bluetooth
has "$PKG_GROUPS" virt && { sudo systemctl enable libvirtd; sudo usermod -aG libvirt "$USER"; }
has "${PICK_apps:-}" piper && sudo systemctl enable ratbagd 2>/dev/null || true
# only one login screen at a time
if [[ $LOGIN_MANAGER != ly ]] && systemctl is-enabled ly@tty1.service >/dev/null 2>&1; then
    sudo systemctl disable ly@tty1.service; sudo systemctl enable getty@tty1.service
fi
case $LOGIN_MANAGER in
    sddm)                 sudo systemctl enable --force sddm ;;
    plasma-login-manager) sudo systemctl enable --force plasmalogin ;;
    ly)
        sudo systemctl disable display-manager.service 2>/dev/null || true
        sudo systemctl disable getty@tty1.service 2>/dev/null || true   # ly takes over tty1 so it shows at boot
        sudo systemctl enable ly@tty1.service ;;
    none)
        sudo systemctl disable display-manager.service 2>/dev/null || true
        line='[[ -z $WAYLAND_DISPLAY && $(tty) == /dev/tty1 ]] && exec start-hyprland'
        for f in "$HOME/.zprofile" "$HOME/.bash_profile"; do
            grep -qF start-hyprland "$f" 2>/dev/null || echo "$line" >> "$f"
        done ;;
esac
[[ $QT_THEME == qt6ct-kde ]] && XDG_MENU_PREFIX=arch- kbuildsycoca6 >/dev/null 2>&1 || true
systemctl --user daemon-reload
systemctl --user enable sync-applications-folder.path 2>/dev/null || true
xdg-user-dirs-update

gum style --border rounded --padding "1 4" --border-foreground 46 \
    "Done! Reboot to start Hyprland." \
    "SUPER+W pick wallpaper · SUPER+CTRL+W light/dark · SUPER+, settings"
