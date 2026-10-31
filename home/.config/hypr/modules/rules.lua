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

-- Workspace per app (icons match the bar: 1 shell · 2 web · 3 code · 4 chat · 5 cinema · 6 launchers · 7 obs · 8 music · 9 running game)
hl.window_rule({
    name      = "ws1-terminal",
    match     = { class = "^(com\\.mitchellh\\.ghostty)$" },
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
-- game launchers and emulator frontends
hl.window_rule({
    name      = "ws6-games",
    match     = { class = "^([Ss]team|heroic|com\\.heroicgameslauncher\\.hgl|[Ll]utris|net\\.lutris\\.Lutris|com\\.usebottles\\.bottles|PrismLauncher|org\\.prismlauncher\\.PrismLauncher|faugus-launcher|itch|minigalaxy|retroarch|dolphin-emu|pcsx2-qt|rpcs3)$" },
    workspace = "6",
})
-- Steam games: tiled on their own workspace, ignoring the game's fullscreen request (SUPER+SHIFT+F still works)
-- shortcut: native games have no shared class like Proton's steam_app_*, so each one is listed here
hl.window_rule({
    name      = "ws9-steam-games",
    match     = { class = "^(steam_app_.*|code-terraform|com\\.factorio\\.Factorio)$" },
    workspace = "9",
    tile      = true,
    suppress_event = "fullscreen",
})
hl.window_rule({
    name      = "ws7-obs",
    match     = { class = "^(com\\.obsproject\\.Studio|obs)$" },
    workspace = "7",
})
hl.window_rule({
    name      = "ws8-music",
    match     = { class = "^(com\\.github\\.th-ch\\.youtube-music|YouTube Music)$" },
    workspace = "8 silent",
})

-- Blur behind the Quickshell bar, popups, launcher and notifications (translucent backgrounds)
hl.layer_rule({
    name  = "blur-quickshell",
    match = { namespace = "^quickshell:(bar|dock|notifications|notifcenter|osd|session)$" },
    blur  = true,
    ignore_alpha = 0.1,
})
-- Twitch chat overlay: visible to me, never captured by OBS / screen sharing
hl.layer_rule({
    name  = "chat-no-screenshare",
    match = { namespace = "^quickshell:chat$" },
    no_screen_share = true,
})
hl.layer_rule({
    name  = "blur-quickshell-launcher",
    match = { namespace = "^quickshell:launcher$" },
    blur  = true,
    ignore_alpha = 0.5, -- blur only the box, not the transparent click-catcher
})
