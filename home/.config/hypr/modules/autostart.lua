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
    hl.exec_cmd("dbus-update-activation-environment --systemd QT_QPA_PLATFORMTHEME XDG_MENU_PREFIX WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("qs")                                      -- bar, launcher, notifications, OSD (~/.config/quickshell); not switchable
    start("/usr/lib/polkit-kde-authentication-agent-1")    -- password prompts for admin actions
    start("/usr/lib/pam_kwallet_init")                     -- unlock KWallet with the login password (secrets for VS Code etc.)
    -- start("waybar")                                     -- old bar (swap back with qs above)
    start("hyprpaper")                                     -- wallpaper
    start("hypridle")                                      -- lock + screen off when idle
    start("nm-applet --indicator")                         -- Wi-Fi/network tray icon
    start("wl-paste --type text --watch cliphist store")   -- clipboard history (text)
    start("wl-paste --type image --watch cliphist store")  -- clipboard history (images)

    for _, cmd in ipairs(S.autostart) do start(cmd) end   -- added in the settings panel
end)
