# Hyprland dotfiles

Hyprland (Lua config) · Quickshell bar/launcher/dock/notifications/OSD/lock · matugen colors from the wallpaper.

## Install on a fresh Arch

Step-by-step from a clean `archinstall`: **[INSTALL.md](INSTALL.md)**.

Requirements: a fresh **Arch Linux** install, a normal user with **sudo**, and internet. Run it as that user, not root.

    bash <(curl -fsSL https://raw.githubusercontent.com/Haddadmj/dotfiles/main/setup.sh)

or `git clone https://github.com/Haddadmj/dotfiles ~/dotfiles && ~/dotfiles/install.sh`.

The installer asks what you want (package groups, terminal, browser, file manager, editor, keyboard
layouts, gaps/borders/rounding, dark/light, NVIDIA hybrid GPU, login screen, zsh), shows the exact
package list for confirmation, backs up existing files to `~/.dotfiles-backup/`, then copies the config.

- Unattended: `cp setup.conf.example my.conf`, edit, `./install.sh -c my.conf -y`
- Change choices later without touching packages: `./install.sh -d`

## Dependencies

Everything below is installed by `install.sh` — this list is so you know what you're getting
(or can install it by hand). **(AUR)** = installed with paru, everything else is in the official repos.

### Installed first (bootstrap)

| Package | Why |
|---|---|
| `git`, `base-devel` | clone this repo, build AUR packages |
| `gum` | the installer's menus |
| `paru-bin` **(AUR)** | AUR helper; built from the AUR if missing |
| `[multilib]` repo | enabled if you say yes — needed for `lib32-*` (NVIDIA, gaming) |

### core — always installed, the desktop won't work without these

| Package | Why |
|---|---|
| `hyprland` | the compositor (0.56+, Lua config) |
| `quickshell` | bar, launcher, dock, notifications, OSD, lock screen, settings panel |
| `matugen` | generates colors from the wallpaper (`scripts/theme.sh`) |
| `hyprpaper` | wallpaper |
| `hypridle`, `hyprlock` | idle timeout, screen lock |
| `hyprlauncher`, `hyprpicker`, `hyprshot`, `hyprshutdown` | app menu, color picker, screenshots, shutdown dialog |
| `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-kde` | screen sharing, file pickers |
| `qt5-wayland`, `qt6-wayland`, `kde-gtk-config`, `breeze-gtk` | Qt/GTK apps on Wayland with matching theme |
| `whitesur-icon-theme`, `whitesur-cursor-theme-git` **(AUR)** | icons and cursor |
| `pipewire`, `pipewire-alsa`, `pipewire-pulse`, `pipewire-jack`, `wireplumber`, `pavucontrol` | audio |
| `networkmanager`, `network-manager-applet` | network + tray icon |
| `bluez`, `bluez-utils` | Bluetooth |
| `polkit-kde-agent`, `kwallet-pam` | admin password prompts, keyring unlock at login |
| `cliphist`, `wl-clipboard` | clipboard history |
| `wofi` | fallback wallpaper picker |
| `wf-recorder`, `satty` | screen recording, screenshot editing |
| `libvips`, `libnotify`, `jq`, `rsync` | wallpaper thumbnails, notifications, scripts |
| `headsetcontrol`, `btop` | headset battery and system monitor in the bar |
| `xdg-user-dirs` | Pictures/Videos/… folders |

### Optional groups (picked in the installer)

| Group | Packages |
|---|---|
| **fonts** | `noto-fonts` `noto-fonts-cjk` `noto-fonts-emoji` `ttf-dejavu` `ttf-liberation` `ttf-jetbrains-mono-nerd` `ttf-meslo-nerd` `ttf-nerd-fonts-symbols` `otf-font-awesome` — *the bar's icons need the Nerd Fonts; strongly recommended* |
| **nvidia** | `nvidia-open` `nvidia-utils` `lib32-nvidia-utils` `nvidia-settings` `nvidia-prime` `libva-nvidia-driver` `linux-headers` |
| **kde-apps** | `dolphin` `dolphin-plugins` `ark` `kate` `okular` `gwenview` `spectacle` `kcalc` `kfind` `ffmpegthumbs` `kdegraphics-thumbnailers` `kio-admin` `partitionmanager` `kwalletmanager` |
| **shell** | `zsh` `fzf` `zoxide` `eza` `bat` `fd` `dust` `duf` `fastfetch` `git-delta` `tldr` `micro` `pkgfile` + oh-my-zsh, powerlevel10k, fzf-tab, zsh-autosuggestions, zsh-syntax-highlighting, zsh-completions, you-should-use (git clones) |
| **apps** | `obsidian` `mpv` `solaar` `piper`, **(AUR)** `vesktop-bin` `code-features` `code-marketplace` `input-remapper-git` `t3code-nightly-bin` `nuviodesktop-bin` |
| **gaming** | `gamemode` `lib32-gamemode` `lib32-pipewire` `lib32-vulkan-icd-loader` `retroarch` + assets/cores `dolphin-emu` `prismlauncher` `kde-games-meta`, **(AUR)** `pcsx2-latest-bin` `rpcs3-bin` |
| **dev** | `cmake` `ninja` `extra-cmake-modules` `jdk17-openjdk` `uv` `scdoc` `blender` `kdenlive` `kdevelop` |
| **virt** | `qemu-desktop` `libvirt` `virt-manager` `edk2-ovmf` `swtpm` `dnsmasq` |

### From your choices

| Choice | Options → package |
|---|---|
| Terminal | `ghostty` · `kitty` · `alacritty` · `foot` |
| Browser | `brave-origin-nightly-bin` (AUR) · `brave-bin` (AUR) · `firefox` · `chromium` · `zen-browser-bin` (AUR) |
| File manager | `dolphin` · `nautilus` · `thunar` · `nemo` |
| Editor | `code` · `kate` · `zed` · `gnome-text-editor` |
| Login screen | `plasma-login-manager` · `sddm` · none (Hyprland starts on TTY1 login) |

Package lists live in `packages/*.txt` — edit them to add or remove things.

## NVIDIA hybrid graphics

If the machine has an NVIDIA card **and** an integrated GPU, the installer can write
`/etc/udev/rules.d/99-gpu-names.rules` (detected from `lspci`) so Hyprland renders on the NVIDIA card.
Without NVIDIA, the NVIDIA-only env vars in `modules/env.lua` are commented out.

## Keybinds to know

`SUPER+,` settings panel · `SUPER+W` pick wallpaper · `SUPER+SHIFT+W` random wallpaper · `SUPER+CTRL+W` light/dark

## Keep it up to date

    ./snapshot.sh && git add -A && git commit -m snapshot && git push

What gets saved is listed in `files.txt`. The wallhaven API key is never committed —
copy `~/.config/wallhaven/apikey` by hand.
