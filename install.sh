#!/usr/bin/env bash
# Hyprland dotfiles installer for Arch Linux.
#   ./install.sh                 ask everything (defaults = the original setup)
#   ./install.sh -c my.conf      take answers from a preset file, ask only what it leaves out
#   ./install.sh -y              accept defaults for anything not in the preset (no questions)
#   ./install.sh -d              dotfiles only: re-apply config + choices, skip packages/services
# Your answers are saved to last-install.conf, so `./install.sh -c last-install.conf -y` repeats a run.
set -euo pipefail
DOT=$(cd "$(dirname "$0")" && pwd)
TS=$(date +%Y%m%d-%H%M%S)

PRESET=""; YES=0; ONLY_DOTS=0
while getopts "c:ydh" o; do
    case $o in
        c) PRESET=$OPTARG ;;
        y) YES=1 ;;
        d) ONLY_DOTS=1 ;;
        *) sed -n '2,7p' "$0"; exit 0 ;;
    esac
done
[[ -n $PRESET ]] && source "$PRESET"

[[ $EUID -eq 0 ]] && { echo "Run as your normal user, not root (sudo is used when needed)."; exit 1; }
command -v pacman >/dev/null || { echo "This installer is for Arch Linux."; exit 1; }

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
    else a=$(gum input --header "$q" --value "$def"); fi
    printf -v "$var" '%s' "${a:-$def}"
}
# askmulti VAR "question" "default1,default2" opt1 opt2 …   → space-separated
askmulti() {
    local var=$1 q=$2 def=$3; shift 3
    [[ -n ${!var:-} ]] && return
    if (( YES )); then printf -v "$var" '%s' "${def//,/ }"; return; fi
    printf -v "$var" '%s' "$(gum choose --no-limit --header "$q" --selected "$def" "$@" | tr '\n' ' ')"
}
has() { [[ " $1 " == *" $2 "* ]]; }
pkgs() { grep -hvE '^\s*#' "${@/#/$DOT/packages/}" | tr -s ' \n' '\n' | grep -v '^$'; }

# ── bootstrap: gum (menus) + paru (AUR) ─────────────────────────────────────────
if (( ONLY_DOTS )); then command -v gum >/dev/null || sudo pacman -S --needed --noconfirm gum
else sudo pacman -S --needed --noconfirm git base-devel gum; fi
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
def_groups="core,fonts,kde-apps,shell"
[[ -n $nv_addr ]] && def_groups+=",nvidia"
def_hybrid=no; [[ -n $nv_addr && -n $ig_addr ]] && def_hybrid=yes

# ── questions ──────────────────────────────────────────────────────────────────
say "What to install"
askmulti PKG_GROUPS "Package groups (space to toggle, enter to confirm)" "$def_groups" \
    core fonts nvidia kde-apps shell apps gaming dev virt
PKG_GROUPS="core ${PKG_GROUPS/core/}"     # core is always installed

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

say "System"
[[ $def_hybrid == yes ]] && info "Hybrid graphics found: NVIDIA $nv_addr + $ig_name $ig_addr"
ask HYBRID_GPU    "Render Hyprland on the NVIDIA GPU (hybrid laptop/desktop udev rule)?" "$def_hybrid" yes no
ask LOGIN_MANAGER "Login screen" plasma-login-manager plasma-login-manager sddm "none (start from TTY1)"
ask MULTILIB      "Enable [multilib] (32-bit libs; needed by nvidia/gaming)?" yes yes no
ask ZSH_SETUP     "Set up zsh + oh-my-zsh + powerlevel10k as your shell?" "$(has "$PKG_GROUPS" shell && echo yes || echo no)" yes no

# remember answers
cat > "$DOT/last-install.conf" <<EOF
PKG_GROUPS="$PKG_GROUPS"
TERMINAL_APP="$TERMINAL_APP"
BROWSER="$BROWSER"
FILE_MANAGER="$FILE_MANAGER"
EDITOR_APP="$EDITOR_APP"
MAIN_MOD="$MAIN_MOD"
KB_LAYOUT="$KB_LAYOUT"
KB_OPTIONS="$KB_OPTIONS"
THEME_MODE="$THEME_MODE"
GAPS_IN="$GAPS_IN"
GAPS_OUT="$GAPS_OUT"
BORDER="$BORDER"
ROUNDING="$ROUNDING"
HYBRID_GPU="$HYBRID_GPU"
LOGIN_MANAGER="$LOGIN_MANAGER"
MULTILIB="$MULTILIB"
ZSH_SETUP="$ZSH_SETUP"
EOF
gum style --border normal --padding "0 2" "$(cat "$DOT/last-install.conf")"

# map app choices to package names / commands
declare -A PKG=([brave-origin-nightly]=brave-origin-nightly-bin [brave]=brave-bin [zen-browser]=zen-browser-bin
                [code]=code [zed]=zed)
declare -A CMD=([zed]=zeditor)   # apps whose command differs from their name

extra=()
for app in "$TERMINAL_APP" "$BROWSER" "$FILE_MANAGER" "$EDITOR_APP"; do extra+=("${PKG[$app]:-$app}"); done
case $LOGIN_MANAGER in sddm) extra+=(sddm) ;; plasma-login-manager) extra+=(plasma-login-manager) ;; esac
[[ $ZSH_SETUP == yes ]] && extra+=(zsh)

files=(); for g in $PKG_GROUPS; do files+=("$g.txt"); done
mapfile -t list < <( { pkgs "${files[@]}"; printf '%s\n' "${extra[@]}"; } | sort -u)
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
if ! paru -S --needed --noconfirm "${list[@]}"; then
    failed=()
    for p in "${list[@]}"; do paru -S --needed --noconfirm "$p" || failed+=("$p"); done
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
    [[ $SHELL == */zsh ]] || chsh -s /usr/bin/zsh
    sudo pkgfile --update >/dev/null 2>&1 || true   # for the command-not-found plugin
fi

# ── services ───────────────────────────────────────────────────────────────────
say "Services"
sudo systemctl enable NetworkManager bluetooth
has "$PKG_GROUPS" virt && { sudo systemctl enable libvirtd; sudo usermod -aG libvirt "$USER"; }
has "$PKG_GROUPS" apps && sudo systemctl enable ratbagd 2>/dev/null || true
case $LOGIN_MANAGER in
    sddm)                 sudo systemctl enable sddm ;;
    plasma-login-manager) sudo systemctl enable plasmalogin ;;
    none*)
        if ! grep -q start-hyprland "$HOME/.zprofile" 2>/dev/null; then
            echo '[[ -z $WAYLAND_DISPLAY && $(tty) == /dev/tty1 ]] && exec start-hyprland' >> "$HOME/.zprofile"
            echo '[[ -z $WAYLAND_DISPLAY && $(tty) == /dev/tty1 ]] && exec start-hyprland' >> "$HOME/.bash_profile"
        fi ;;
esac
systemctl --user daemon-reload
systemctl --user enable sync-applications-folder.path 2>/dev/null || true
xdg-user-dirs-update

gum style --border rounded --padding "1 4" --border-foreground 46 \
    "Done! Reboot to start Hyprland." \
    "SUPER+W pick wallpaper · SUPER+CTRL+W light/dark · SUPER+, settings"
