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
| `packages/` | Explicitly-installed package lists, for rebuilding a machine |

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
./install.sh -n     # dry run first — shows exactly what it would touch
./install.sh
```

`install.sh` symlinks everything into `~/.config`, `~/.local/bin` and
`~/.local/share`. Anything it would overwrite is moved to
`~/.dotfiles-backup/<timestamp>/` first, so the run is reversible. Use
`./install.sh -c` to copy instead of symlink.

Then either log out and back in, or `hyprctl reload`.

### Packages

```sh
sudo pacman -S --needed - < packages/pacman.txt
paru  -S --needed - < packages/aur.txt
```

`packages/aur.txt` includes some machine-specific things (Steam/Proton, emulator
and launcher packages, `xpadneo-dkms` for a controller). Skim it and drop what
you don't want rather than installing it wholesale.

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

They're committed anyway so a fresh clone looks right before you've picked a
wallpaper.

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

## Notes if you're adapting this

- **Hyprland is configured in Lua, not hyprlang.** That puts it on the
  non-legacy config parser, where `hyprctl keyword` silently does nothing — use
  `hyprctl eval` instead. Most advice you'll find online assumes the old parser.
- **`monitors.lua` is generic** (`output = ""`, preferred mode, auto position),
  so it should come up sane on any display, but it's the first thing to adjust.
- **`autostart.lua` restarts the xdg-desktop-portal services on login** to work
  around a startup race that otherwise kills screen capture for the session.
  Keep it unless you know you don't need it.
- **Quickshell IPC handlers must not be named `show`** — the `qs` CLI swallows
  it as its own `ipc show` subcommand and the call becomes a silent no-op.
- `config/mimeapps.list` and `gamemode.ini` are personal defaults; harmless, but
  they're preferences rather than part of the desktop.
