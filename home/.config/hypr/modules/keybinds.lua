-- See https://wiki.hypr.land/Configuring/Basics/Binds/
local P = require("modules.programs")
local mainMod = P.mainMod
local scripts = os.getenv("HOME") .. "/.config/hypr/scripts"

local S = require("modules.settings")
local disabled = S.set(S.disabledBinds)

-- Binds with a description show up in the Quickshell cheat sheet (SUPER+/) and can be
-- re-keyed or turned off in the settings panel (SUPER+,), which stores that by description.
-- Format: "Group|What it does", or "Group|What it does|key label" to override the shown keys
-- (those with a key label are fixed, e.g. the workspace loop).
local function bind(keys, action, desc, opts)
    if desc and disabled[desc] then return end
    if desc and S.remap[desc] then keys = S.remap[desc] end
    opts = opts or {}
    opts.description = desc
    hl.bind(keys, action, opts)
end

-- Apps
bind(mainMod .. " + Return", hl.dsp.exec_cmd(P.terminal), "Apps|Terminal")
bind(mainMod .. " + F", hl.dsp.exec_cmd(P.fileManager), "Apps|File manager")
bind(mainMod .. " + B", hl.dsp.exec_cmd(P.browser), "Apps|Browser")
bind(mainMod .. " + E", hl.dsp.exec_cmd(P.editor), "Apps|Editor")
bind(mainMod .. " + R", hl.dsp.exec_cmd("qs ipc call launcher toggle"), "Apps|Launcher")  -- quickshell launcher
bind(mainMod .. " + D", hl.dsp.exec_cmd("qs ipc call dock toggle"), "Apps|Toggle dock")  -- quickshell dock
bind("ALT + SPACE", hl.dsp.exec_cmd("vicinae toggle"), "Apps|Vicinae")  -- Raycast-style launcher (server started in autostart.lua)

-- Theme: pick a wallpaper (colors follow) / random wallpaper / toggle light-dark
bind(mainMod .. " + W",         hl.dsp.exec_cmd(scripts .. "/theme.sh pick"),        "Theme|Pick wallpaper")
bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd(scripts .. "/theme.sh random"),      "Theme|Random wallpaper")
bind(mainMod .. " + CTRL + W",  hl.dsp.exec_cmd(scripts .. "/theme.sh toggle-mode"), "Theme|Toggle light / dark")

-- Windows / session
bind(mainMod .. " + Q", hl.dsp.window.close(), "Windows|Close window")
bind(mainMod .. " + M", hl.dsp.exec_cmd("qs ipc call session toggle"), "Session|Power menu")  -- quickshell session menu
bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }), "Windows|Toggle floating")
bind(mainMod .. " + P", hl.dsp.window.pseudo(), "Windows|Pseudo-tile")
bind(mainMod .. " + J", hl.dsp.layout("togglesplit"), "Windows|Toggle split direction")    -- dwindle only
bind(mainMod .. " + L", hl.dsp.exec_cmd("loginctl lock-session"), "Session|Lock screen")

-- Utilities
bind(mainMod .. " + C", hl.dsp.exec_cmd("qs ipc call launcher clipboard"), "Tools|Clipboard history")  -- clipboard history (quickshell launcher)
bind(mainMod .. " + N", hl.dsp.exec_cmd("qs ipc call notifications toggle"), "Shell|Notification center")  -- notification center
bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"), "Tools|Color picker")          -- color picker -> clipboard
bind("Print", hl.dsp.exec_cmd("hyprshot -m region --clipboard-only"), "Screenshots|Region to clipboard")      -- screenshot region
bind("SHIFT + Print", hl.dsp.exec_cmd("hyprshot -m output -o ~/Pictures/Screenshots"), "Screenshots|Full screen to file")  -- full screen to file
bind(mainMod .. " + Print",  hl.dsp.exec_cmd("qs ipc call screenshot toggle"), "Screenshots|Capture / record menu")     -- screenshot / record menu
bind(mainMod .. " + A",      hl.dsp.exec_cmd("qs ipc call quicksettings toggle"), "Shell|Quick settings")  -- quick settings
bind(mainMod .. " + Tab",    hl.dsp.exec_cmd("qs ipc call overview toggle"), "Shell|Workspace overview")       -- workspace overview
bind(mainMod .. " + period", hl.dsp.exec_cmd("qs ipc call launcher emoji"), "Tools|Emoji picker")
bind(mainMod .. " + slash",  hl.dsp.exec_cmd("qs ipc call cheatsheet toggle"), "Shell|This cheat sheet")
bind(mainMod .. " + comma",  hl.dsp.exec_cmd("qs ipc call hyprsettings toggle"), "Shell|Hyprland settings")        -- emoji picker
bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("pkill -x qs; sleep 0.3; qs"), "Shell|Restart Quickshell")  -- after editing files it doesn't hot-reload (e.g. Icons.qml)

-- Move focus with mainMod + arrow keys
bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }), "Windows|Move focus|SUPER + ← ↑ → ↓")
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    -- only the first of each gets a description, so the cheat sheet shows one row
    bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i}),         i == 1 and "Workspaces|Go to workspace|SUPER + 1…0" or nil)
    bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }), i == 1 and "Workspaces|Move window to workspace|SUPER + SHIFT + 1…0" or nil)
end

-- Special workspace (scratchpad)
bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"), "Workspaces|Toggle scratchpad")
bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }), "Workspaces|Move window to scratchpad")

-- Scroll through existing workspaces with mainMod + scroll
bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), "Workspaces|Next / previous workspace|SUPER + scroll")
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   "Windows|Move window|SUPER + left drag",  { mouse = true })
bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), "Windows|Resize window|SUPER + right drag", { mouse = true })

-- Multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })

-- Requires playerctl
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
