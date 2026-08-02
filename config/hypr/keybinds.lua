---------------------
---- MY PROGRAMS ----
---------------------

-- Set programs that you use
local terminal    = "alacritty"
local fileManager = "thunar"
local browser     = "brave-nightly"
local runner = "rofi -show run"
local bin         = os.getenv("HOME") .. "/.local/bin/"
local screenshot  = bin .. "screenshot"
local cheatsheet  = bin .. "keybind-cheatsheet"
local powermenu   = bin .. "powermenu"
local wallpaper   = bin .. "wallpaper"
local gameMode    = bin .. "game-mode"

-- cliphist keeps the history; rofi picks from it and the choice goes back on
-- the clipboard. Piped through a shell because hl.exec_cmd is not one.
local clipboard = "sh -c 'cliphist list | rofi -dmenu -i -p Clipboard | cliphist decode | wl-copy'"

-- Quickshell launchers (see ~/.config/quickshell)
local appGrid   = "qs ipc call launcher grid" -- GNOME-style fullscreen grid
local startMenu = "qs ipc call launcher menu" -- Windows-style start menu
local switcher  = "qs ipc call windows toggle" -- alt-tab overlay

---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER" -- Sets "Windows" key as main modifier
local secondMod = "SUPER + SHIFT" -- Sets "Windows" key as main modifier
local thirdMod = "SUPER + ALT"

-- The `description` on each bind is what the cheat sheet (SUPER + /) shows, so
-- keep it filled in when adding a bind -- undescribed binds are listed as such.
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal), { description = "Open terminal" })
hl.bind(mainMod .. " + Q", hl.dsp.window.close(), { description = "Close active window" })
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd(powermenu), { description = "Power menu (lock / suspend / log out / reboot / shut down)" })
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"), { description = "Lock the screen" })
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd(fileManager), { description = "Open file manager" })
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser), { description = "Open browser" })
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd(clipboard), { description = "Clipboard history" })
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(appGrid), { description = "App grid (fullscreen launcher)" })
hl.bind(thirdMod .. " + SPACE", hl.dsp.exec_cmd(startMenu), { description = "Start menu" })
hl.bind(secondMod .. " + SPACE", hl.dsp.exec_cmd(runner), { description = "Run command (rofi)" })
hl.bind(mainMod .. " + TAB", hl.dsp.exec_cmd(switcher), { description = "Window switcher (most recent first)" })
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo(), { description = "Toggle pseudo-tiling" })
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"), { description = "Toggle split direction (dwindle)" })

-- Show every bind in a searchable rofi list, generated from the live bind table
hl.bind(mainMod .. " + slash", hl.dsp.exec_cmd(cheatsheet), { description = "Show this keybind cheat sheet" })

-- Screenshots (saved to ~/Pictures/Screenshots and copied to the clipboard).
-- Every mode that asks for a selection freezes the screen first, so a menu or
-- a hover state stays on screen while the region is drawn.
hl.bind("PRINT",             hl.dsp.exec_cmd(screenshot .. " full"),   { description = "Screenshot: whole desktop" })
hl.bind("SHIFT + PRINT",     hl.dsp.exec_cmd(screenshot .. " region"), { description = "Screenshot: drag a region" })
hl.bind("ALT + PRINT",       hl.dsp.exec_cmd(screenshot .. " window"), { description = "Screenshot: focused window" })
hl.bind(mainMod .. " + PRINT", hl.dsp.exec_cmd(screenshot .. " menu"), { description = "Screenshot: pick a mode" })
hl.bind(secondMod .. " + E", hl.dsp.exec_cmd(screenshot .. " edit"),   { description = "Screenshot: region, then annotate" })
hl.bind(secondMod .. " + O", hl.dsp.exec_cmd(screenshot .. " ocr"),    { description = "OCR a region to the clipboard" })
hl.bind(secondMod .. " + C", hl.dsp.exec_cmd(screenshot .. " color"),  { description = "Pick a colour to the clipboard" })

-- Desktop
hl.bind(secondMod .. " + W", hl.dsp.exec_cmd(wallpaper .. " -r"),   { description = "Random wallpaper (retheme everything)" })
hl.bind(secondMod .. " + R", hl.dsp.exec_cmd("hyprctl reload"),     { description = "Reload the Hyprland config" })
hl.bind(thirdMod .. " + G",  hl.dsp.exec_cmd(gameMode .. " toggle"), { description = "Toggle game mode (effects off, performance profile)" })

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }),  { description = "Focus window left" })
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }), { description = "Focus window right" })
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }),    { description = "Focus window up" })
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }),  { description = "Focus window down" })

-- Move focus with mainMod + arrow keys
hl.bind(secondMod .. " + left",  hl.dsp.window.move({ direction = "left" }),  { description = "Move window left" })
hl.bind(secondMod .. " + right", hl.dsp.window.move({ direction = "right" }), { description = "Move window right" })
hl.bind(secondMod .. " + up",    hl.dsp.window.move({ direction = "up" }),    { description = "Move window up" })
hl.bind(secondMod .. " + down",  hl.dsp.window.move({ direction = "down" }),  { description = "Move window down" })

hl.bind(secondMod .. " + T", hl.dsp.window.float({ action = "toggle" }),      { description = "Toggle floating" })
hl.bind(secondMod .. " + F", hl.dsp.window.fullscreen({ action = "toggle" }), { description = "Toggle fullscreen" })


-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,   hl.dsp.focus({ workspace = i}),        { description = "Switch to workspace " .. i })
    hl.bind(secondMod .. " + " .. key, hl.dsp.window.move({ workspace = i }), { description = "Move window to workspace " .. i })
end

-- Example special workspace (scratchpad)
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"),             { description = "Toggle scratchpad" })
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }),  { description = "Move window to scratchpad" })

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "Next workspace" })
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }), { description = "Previous workspace" })

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true, description = "Drag window" })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Resize window" })

-- Volume. `locked = true` keeps these working while hyprlock is up.
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true, description = "Volume up" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true, description = "Volume down" })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, description = "Mute output" })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, description = "Mute microphone" })

-- Media transport (playerctl)
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true, description = "Next track" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Play / pause" })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Play / pause" })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true, description = "Previous track" })

-- No backlight on a desktop monitor, so XF86MonBrightness* are left unbound;
-- brightnessctl is not installed. Bind them here if a laptop ever shares this
-- config.
