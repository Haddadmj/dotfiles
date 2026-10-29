-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/

hl.window_rule({
    -- Ignore maximize requests from all apps
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move  = "20 monitor_h-120",
    float = true,
})

-- Blur behind waybar (it uses a translucent background)
hl.layer_rule({
    name  = "blur-waybar",
    match = { namespace = "^waybar$" },
    blur  = true,
    ignore_alpha = 0.1, -- only blur the islands, not the transparent bar
})

-- Calendar popup from the waybar clock
hl.window_rule({
    name  = "waybar-calendar",
    match = { class = "^zenity$", title = "^Calendar$" },
    float = true,
    move  = "monitor_w-480 60",
})

-- Workspace per app (icons match the bar: 1 shell · 2 web · 3 code · 4 chat · 5 cinema · 6 games)
hl.window_rule({
    name      = "ws1-terminal",
    match     = { class = "^(kitty|com\\.mitchellh\\.ghostty)$" },
    workspace = "1",
})
hl.window_rule({
    name      = "ws2-browser",
    match     = { class = "^(brave.*)$" },
    workspace = "2",
})
hl.window_rule({
    name      = "ws3-code",
    match     = { class = "^([Cc]ode|code-oss|code-url-handler)$" },
    workspace = "3",
})
hl.window_rule({
    name      = "ws4-discord",
    match     = { class = "^([Dd]iscord|vesktop|equibop|legcord|[Ww]eb[Cc]ord)$" },
    workspace = "4",
})
hl.window_rule({
    name      = "ws5-cinema",
    match     = { class = "^(com-nuvio-app-MainKt|[Nn]uvio|com\\.stremio\\.[Ss]tremio|[Ss]tremio|com\\.github\\.iwalton3\\.jellyfin-media-player|org\\.jellyfin\\..*|[Pp]lex.*|[Kk]odi)$" },
    workspace = "5",
})
-- game launchers and emulator frontends (games started from them open wherever you are, usually here)
hl.window_rule({
    name      = "ws6-games",
    match     = { class = "^([Ss]team|heroic|com\\.heroicgameslauncher\\.hgl|[Ll]utris|net\\.lutris\\.Lutris|com\\.usebottles\\.bottles|PrismLauncher|org\\.prismlauncher\\.PrismLauncher|faugus-launcher|itch|minigalaxy|retroarch|dolphin-emu|pcsx2-qt|rpcs3)$" },
    workspace = "6",
})

-- Blur behind the Quickshell bar, popups, launcher and notifications (translucent backgrounds)
hl.layer_rule({
    name  = "blur-quickshell",
    match = { namespace = "^quickshell:(bar|dock|notifications|notifcenter|osd)$" },
    blur  = true,
    ignore_alpha = 0.1,
})
hl.layer_rule({
    name  = "blur-quickshell-launcher",
    match = { namespace = "^quickshell:launcher$" },
    blur  = true,
    ignore_alpha = 0.5, -- blur only the box, not the transparent click-catcher
})
