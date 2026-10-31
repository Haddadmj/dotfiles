-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

-- cursor theme and size chosen with scripts/appearance.sh (SUPER+U, SUPER+CTRL+U)
local function cursorState(name)
    local f = io.open(os.getenv("HOME") .. "/.config/hypr/" .. name)
    if not f then return nil end
    local value = f:read("l")
    f:close()
    return value
end

local cursorSize = cursorState("cursor-size") or "24"
hl.env("XCURSOR_SIZE", cursorSize)
hl.env("HYPRCURSOR_SIZE", cursorSize)

local cursorTheme = cursorState("cursor-theme")
if cursorTheme then
    hl.env("XCURSOR_THEME", cursorTheme)
    hl.env("HYPRCURSOR_THEME", cursorTheme)
end

-- Qt/KDE apps (Dolphin etc.) follow kdeglobals colors instead of the default light Fusion look
hl.env("QT_QPA_PLATFORMTHEME", "kde")
hl.env("XDG_MENU_PREFIX", "plasma-") -- lets Dolphin's "Open With" find applications

-- NVIDIA
hl.env("LIBVA_DRIVER_NAME", "nvidia")            -- hardware video decode (VA-API)
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("NVD_BACKEND", "direct")                  -- for libva-nvidia-driver
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")   -- Electron apps run natively on Wayland
hl.env("AQ_DRM_DEVICES", "/dev/dri/nvidia-gpu:/dev/dri/amd-igpu") -- render on the 4070 (udev symlinks)

hl.env("TERMINAL", "ghostty")                    -- default terminal for scripts/apps that read $TERMINAL
hl.env("EDITOR", "micro")                        -- .zshrc only covers shells; apps started outside zsh fell back to vim
hl.env("VISUAL", "micro")
