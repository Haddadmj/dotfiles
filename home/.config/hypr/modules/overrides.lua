-- Applies what the Quickshell Hyprland settings panel (SUPER+,) saved in settings.json
-- (see modules/settings.lua). Loaded last, so it wins over the other modules.
local S = require("modules.settings")

-- options: flat "a:b:c" keys -> nested hl.config table
local cfg = {}
for key, v in pairs(S.options) do
    local t, parts = cfg, {}
    for p in key:gmatch("[^:]+") do parts[#parts + 1] = p end
    for i = 1, #parts - 1 do
        t[parts[i]] = t[parts[i]] or {}
        t = t[parts[i]]
    end
    t[parts[#parts]] = v
end
hl.config(cfg)

for name, v in pairs(S.env) do hl.env(name, tostring(v)) end

-- custom binds replace whatever else was on those keys
for _, b in ipairs(S.binds) do
    if b.keys and b.cmd and b.keys ~= "" and b.cmd ~= "" then
        pcall(hl.unbind, b.keys)
        hl.bind(b.keys, hl.dsp.exec_cmd(b.cmd), { description = "Custom|" .. ((b.name or "") ~= "" and b.name or b.cmd) })
    end
end
