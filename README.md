# dotfiles

Arch Linux + Hyprland desktop: config, theming pipeline, and helper scripts.

The bar, dock, launcher and window switcher are a hand-written **Quickshell**
(QML) setup rather than Waybar/rofi-for-everything, and the whole colour scheme
is regenerated from the current wallpaper by a single `wallpaper` command.

## What's in here

| Path | What it is |
| --- | --- |
| `config/hypr/` | Hyprland, split into Lua modules (`hyprland.lua` requires the rest) |
| `config/quickshell/` | The shell itself — bar, dock, app launcher, alt-tab switcher, tray, clipboard |
| `config/matugen/` | Templates that turn a wallpaper's palette into every app's colours |
| `config/alacritty/`, `rofi/`, `wlogout/`, `gtk-3.0/`, `gtk-4.0/`, `qt6ct/` | Terminal, menus, logout screen, widget theming |
| `local/bin/` | Helper scripts — see below |
| `local/share/wallpaper-theme/` | `gen-terminal.py`, the terminal-palette generator the `wallpaper` script calls |
| `defaults/` | Neutral fallback colours, seeded on install when no themed file exists |
| `packages/` | Commented, grouped package lists for rebuilding a machine |

### Scripts (`local/bin/`)

| Script | Does |
| --- | --- |
| `wallpaper` | Downloads/sets a wallpaper and retheme everything from it. The centrepiece — see below. |
| `screenshot` | Region / window / screen capture with annotation and clipboard handling |
| `powermenu` | wlogout-style power menu |
| `game-mode` | Toggles the compositor into a low-latency gaming state |
| `controller` | DualSense / Xbox pad pairing and battery helper |
| `steam-launch-options` | Generates per-game Steam launch option strings |
| `keybind-cheatsheet` | Parses `keybinds.lua` and shows every binding in a rofi overlay |
| `rofi-bluetooth` | Bluetooth device menu |

## Install

```sh
git clone https://github.com/Haddadmj/dotfiles ~/dotfiles
cd ~/dotfiles
```

**Always dry-run first.** `-n` prints every file it would replace, back up and
link, and changes nothing:

```sh
./install.sh -n
```

Read that output. If you're happy with what it says it will do, run it for real:

```sh
./install.sh
```

`install.sh` symlinks everything into `~/.config`, `~/.local/bin` and
`~/.local/share`. Anything it would overwrite is moved to
`~/.dotfiles-backup/<timestamp>/` first, so the run is reversible. Use
`./install.sh -c` to copy instead of symlink.

Then either log out and back in, or `hyprctl reload`.

### Uninstall

```sh
./install.sh -u -n    # again, preview first
./install.sh -u
```

Removes only symlinks that point into this repo — real files, and links pointing
anywhere else, are left alone — then restores the newest backup over the gaps.
Anything already in place is left in the backup rather than overwritten, and the
backup directory is never deleted.

### Packages

Both lists are commented and grouped by section, so you can delete whole
categories you don't want. The `sed` strips the comments, which pacman can't
parse:

```sh
sed 's/#.*//' packages/pacman.txt | sudo pacman -S --needed -
sed 's/#.*//' packages/aur.txt    | paru -S --needed -
```

Only the **Hyprland desktop** and **Fonts** sections are actually required.
Base-system, NVIDIA, gaming, emulation and personal-application sections are
labelled and safe to drop. Read `packages/pacman.txt` before running it — the
base section assumes an AMD CPU, btrfs and GRUB/EFI.

## The wallpaper → colour pipeline

This is the part worth understanding before editing anything colour-related.

```
wallpaper  ──▶  matugen  ──▶  config/matugen/templates/*  ──▶  generated files
```

Running `wallpaper` extracts a palette from the image and matugen renders each
template to its destination. **These destinations are generated — editing them
does nothing, the next `wallpaper` run overwrites them:**

- `config/hypr/colors.lua`
- `config/hypr/hyprlock.conf`
- `config/quickshell/Colors.qml`
- `config/wlogout/style.css`
- `config/gtk-3.0/colors.css`, `config/gtk-4.0/colors.css`
- `config/alacritty/colors.toml`

To change how something is coloured, edit the matching file in
`config/matugen/templates/` (or `local/share/wallpaper-theme/gen-terminal.py`
for the terminal palette), then re-run `wallpaper`.

Those seven paths are **gitignored**, so retheming doesn't leave the repo dirty
on every wallpaper change. A neutral grey-blue fallback for each lives in
`defaults/`, and `install.sh` seeds it only where no themed file exists — which
matters because `look.lua` does `require("colors")` and most of the Quickshell
QML references `Colors.`, so a clone missing them would fail to start a session
at all. Run `wallpaper` once and your real colours replace the fallback.

### Wallhaven API key

`wallpaper` can pull images from Wallhaven, which needs an API key for NSFW-
capable searches. It reads `$WALLHAVEN_API_KEY`, falling back to
`~/.config/wallpaper/wallhaven-key`.

**That key is deliberately not in this repo.** Get your own from
<https://wallhaven.cc/settings/account> and drop it in:

```sh
mkdir -p ~/.config/wallpaper
printf '%s' 'YOUR_KEY' > ~/.config/wallpaper/wallhaven-key
chmod 600 ~/.config/wallpaper/wallhaven-key
```

Everything except Wallhaven search works fine without it.
