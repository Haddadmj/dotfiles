-- See https://wiki.hypr.land/Configuring/Basics/Autostart/
-- start() entries are listed in the settings panel (SUPER+,), which can turn them off or add more
-- (stored in settings.json). Keep one start("…") per line so the panel can read them; the trailing
-- comment is shown as its description.
local S = require("modules.settings")
local off = S.set(S.disabledAutostart)
local function start(cmd)
    if not off[cmd] then hl.exec_cmd(cmd) end
end

hl.on("hyprland.start", function ()
    -- export env to D-Bus/systemd so D-Bus-activated apps (Dolphin) get the Qt theme too
    -- then restart the Hyprland portal: if it started before Wayland was up it gives up for good (no screen sharing / OBS capture)
    hl.exec_cmd("dbus-update-activation-environment --systemd QT_QPA_PLATFORMTHEME XDG_MENU_PREFIX WAYLAND_DISPLAY XDG_CURRENT_DESKTOP && systemctl --user reset-failed xdg-desktop-portal-hyprland; systemctl --user restart xdg-desktop-portal-hyprland")
    hl.exec_cmd("qs")                                      -- bar, launcher, notifications, OSD (~/.config/quickshell); not switchable
    start("/usr/lib/polkit-kde-authentication-agent-1")    -- password prompts for admin actions
    start("/usr/lib/pam_kwallet_init")                     -- unlock KWallet with the login password (secrets for VS Code etc.)
    start("hyprpaper")                                     -- wallpaper
    start("hypridle")                                      -- lock + screen off when idle
    start("nm-applet --indicator")                         -- Wi-Fi/network tray icon
    start("wl-paste --type text --watch cliphist store")   -- clipboard history (text)
    start("wl-paste --type image --watch cliphist store")  -- clipboard history (images)
    start("vicinae server")                                -- Vicinae launcher backend (ALT+SPACE)

    for _, cmd in ipairs(S.autostart) do start(cmd) end   -- added in the settings panel
end)
