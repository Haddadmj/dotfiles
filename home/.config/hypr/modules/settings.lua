-- Settings saved by the Quickshell Hyprland settings panel (SUPER+,) in ~/.config/hypr/settings.json:
--   options            { "general:gaps_in": 6, … }        applied by overrides.lua
--   binds              [{ keys, cmd, name }]               custom exec binds (overrides.lua)
--   remap              { "<bind description>": "keys" }    new keys for a bind (keybinds.lua)
--   disabledBinds      ["<bind description>", …]          (keybinds.lua)
--   env                { NAME: "value" }                   wins over env.lua (overrides.lua)
--   autostart          ["command", …]                     extra commands at login (autostart.lua)
--   disabledAutostart  ["command", …]                     (autostart.lua)
local S = {}
local f = io.open(os.getenv("HOME") .. "/.config/hypr/settings.json")
if f then
    local ok, t = pcall(require("modules.json").decode, f:read("a"))
    f:close()
    if ok and type(t) == "table" then S = t end
end
for _, k in ipairs({ "options", "binds", "remap", "disabledBinds", "env", "autostart", "disabledAutostart" }) do
    if type(S[k]) ~= "table" then S[k] = {} end
end

-- list -> set
function S.set(list)
    local t = {}
    for _, v in ipairs(list) do t[v] = true end
    return t
end

return S
