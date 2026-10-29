-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

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
