# Installing from a clean Arch (archinstall)

## 1. Boot the Arch ISO

Boot the USB, then get online:

- Ethernet: works automatically.
- Wi-Fi:
  ```
  iwctl
  station wlan0 connect "Your-WiFi"
  exit
  ```

Check with `ping -c2 archlinux.org`, then run `archinstall`.

## 2. archinstall choices

Only the options that matter for this setup are listed; everything else is up to you.

| Option | Pick | Why |
|---|---|---|
| Mirrors | your region | faster downloads |
| Disk configuration | *Use a best-effort default partition layout* → ext4 or btrfs | |
| Bootloader | GRUB or systemd-boot | either works |
| **Authentication → User account** | create your user, **Superuser (sudo): yes** | the installer runs as this user with sudo |
| **Profile** | **Minimal** | `install.sh` installs Hyprland, drivers and apps itself. Don't pick the Hyprland/KDE desktop profile, it pulls in a different set of apps |
| **Audio** | **Pipewire** | |
| Kernels | **linux** | `nvidia-open` is built for the stock `linux` kernel |
| **Network configuration** | **Use NetworkManager** | otherwise there's no network after the reboot |
| **Optional repositories** | **multilib** | needed for NVIDIA 32-bit libs and gaming (the installer can also enable it later) |
| Additional packages | `git` | optional; the installer installs it too |
| Timezone / locale / keyboard | yours | |

Select **Install**, wait, then choose **no** to chroot and `reboot`. Remove the USB.

## 3. First boot (text console)

Log in as **your user**, not root.

Connect to Wi-Fi if you're not on Ethernet:
```
nmcli device wifi connect "Your-WiFi" password "your-password"
```

### Optional: work over SSH (VM or second PC)

Clipboard sharing into a VM is unreliable (SPICE's `spice-vdagent` barely supports Wayland), so it's easier
to SSH in from your main machine and copy and paste in your own terminal.

In the new install:
```
sudo pacman -S openssh
sudo systemctl enable --now sshd
ip -4 addr          # note the IP, e.g. 192.168.122.x on virt-manager's default network
```

From your main machine:
```
ssh youruser@192.168.122.x
```

If you can't read the IP inside the VM, run `sudo virsh domifaddr <vm-name>` on the host (`virsh list --all` shows the name).

Copy files over the same connection (after step 4, once the folders exist):
```
scp ~/.config/wallhaven/apikey youruser@192.168.122.x:~/.config/wallhaven/
scp -r ~/Pictures/Wallpapers youruser@192.168.122.x:~/Pictures/
```

Run step 4 in that SSH session. For step 5, keep the VM window open to watch the login screen come up.
To turn SSH off afterwards: `sudo systemctl disable --now sshd`.

## 4. Run the installer

```
bash <(curl -fsSL https://raw.githubusercontent.com/Haddadmj/dotfiles/main/setup.sh)
```

This clones the repo to `~/dotfiles` and starts `install.sh`:

1. Enter your sudo password — **only once**; it stays unlocked until the installer finishes. It installs `git`, `base-devel` and `gum`, then builds `paru`.
2. Answer the menus. Arrow keys to move, **x** to tick/untick, **ctrl+a** to tick all, **enter** to confirm.
   No groups are ticked at first — core (Hyprland, the shell, fonts, audio, network) is always installed.
   For a desktop like the original, tick `fonts kde-apps shell`, plus `nvidia` on an NVIDIA machine
   (the installer says so when it finds one), and `apps`/`gaming`/`dev`/`virt` if you want them.
   Each ticked group then opens a list of its apps, all ticked — untick what you don't want.
   The other questions default to the original setup; just press enter to keep them.
3. Check the settings summary and package list, then confirm.
4. AUR builds take a while; no more password prompts after the first one.

**Just Hyprland, no Plasma:** keep the default `sddm` (or pick `ly`) for the login screen and the default `qt6ct-kde` for Qt theming.
`plasma-login-manager` and `plasma-integration` both pull in Plasma.

Re-running is safe: installed packages are skipped and replaced files are backed up to `~/.dotfiles-backup/`.

## 5. Reboot

```
reboot
```

- **sddm / ly / plasma-login-manager:** pick the **Hyprland** session and log in (ly: arrow keys switch the session).
- **none:** log in on TTY1 and Hyprland starts automatically.

## 6. After the first login

- Wallpaper and colors: `SUPER+W` to pick a wallpaper, `SUPER+CTRL+W` for light/dark.
- Settings panel: `SUPER+,`.
- Wallhaven API key (not in the repo): put it in `~/.config/wallhaven/apikey`.
- Add more wallpapers to `~/Pictures/Wallpapers`.

## Troubleshooting

| Problem | Fix |
|---|---|
| Black screen / Hyprland won't start on NVIDIA | Switch to a TTY (`CTRL+ALT+F2`), check `~/.local/share/hyprland/hyprland.log`. On a non-hybrid machine, make sure the `AQ_DRM_DEVICES` line in `~/.config/hypr/modules/env.lua` is commented out. |
| A package failed to install | The installer prints which ones. Run `paru -S <name>` by hand, or remove it from `packages/*.txt`. |
| Want different choices later | `~/dotfiles/install.sh -d` re-applies config and choices without touching packages. |
| No icons in the bar | The bar needs `ttf-jetbrains-mono-nerd` (core). Check with `fc-list \| grep -i jetbrains`; if missing, `sudo pacman -S ttf-jetbrains-mono-nerd`. |
| Plasma got installed (older installer) | `sudo pacman -Rns plasma-login-manager xdg-desktop-portal-kde plasma-integration plasma-workspace`, then re-run `install.sh` and pick `sddm`/`ly` + `qt6ct-kde`. |
