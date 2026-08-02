--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

-- Example window rules that are useful

local suppressMaximizeRule = hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})
-- suppressMaximizeRule:set_enabled(false)

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

-- RetroArch asks the compositor for fullscreen itself (video_fullscreen = true
-- in retroarch.cfg), so this rule only needs to pin it to a workspace -- no
-- fullscreen_state override required, unlike the games rule further down.
hl.window_rule({
    name  = "retroarch-on-2",
    match = { class = "^com\\.libretro\\.RetroArch$" },

    workspace = "2",
})

-- Layer rules also return a handle.
-- local overlayLayerRule = hl.layer_rule({
--     name  = "no-anim-overlay",
--     match = { namespace = "^my-overlay$" },
--     no_anim = true,
-- })
-- overlayLayerRule:set_enabled(false)

-- Hyprland-run windowrule
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

hl.window_rule({
    -- Bitwarden extension popup (Brave) should float, not tile
    name  = "float-bitwarden",
    match = { title = "^Bitwarden$" },

    float = true,
})

hl.window_rule({
    -- Terminal spawned by the bar's update counter
    name  = "float-system-update",
    match = { class = "^hypr-update$" },

    float = true,
    size  = "900 600",
    center = true,
})

-- Minecraft needs two rules because it identifies itself differently per backend.
--
-- Under XWayland, LWJGL sets the class to "Minecraft* <version>" (the asterisk
-- means a modified/modded instance); the loading window is
-- "Minecraft: NeoForge Loading...". "^Minecraft" covers every version/loader.
hl.window_rule({
    name  = "minecraft-tile-on-3-xwayland",
    match = { class = "^Minecraft" },

    workspace = "3 silent",
    tile      = true,
})

-- Under native Wayland the class is EMPTY: the xdg app_id comes from GLFW's
-- GLFW_WAYLAND_APP_ID window hint, which Minecraft never sets, and there is no
-- env var or launcher option to inject one. So match on title instead, and pin
-- it to class="^$" so a browser tab about Minecraft can't trigger the rule.
-- Unanchored -- the title is "Minecraft: NeoForge Loading..." at map time and
-- "<pack> - Minecraft <version>" once the game is up.
hl.window_rule({
    name  = "minecraft-tile-on-3-wayland",
    match = { class = "^$", title = "Minecraft" },

    workspace = "3 silent",
    tile      = true,
})

-- --------------------------------
-- ---- GAMES -> WORKSPACE 5 ------
-- --------------------------------

-- Steam titles get class "steam_app_<appid>" (verified against steam_app_2313700),
-- so the whole library is covered by one pattern. The Steam client itself is
-- plain "steam" and is deliberately not matched. "gamescope" is here because it
-- is the fallback wrapper for games that ignore the rules below.
-- Add other launchers once their class is confirmed with:
--   hyprctl clients -j | grep -E '"class"|"title"'
hl.window_rule({
    name  = "games-tile-on-5",
    match = { class = "^(steam_app_\\d+|gamescope)$" },

    workspace      = "5 silent",
    tile           = true,
    suppress_event = "fullscreen",

    -- Games that boot straight into fullscreen ignore suppress_event, because
    -- they never ask the compositor -- they just render at monitor size.
    -- "0 2" keeps Hyprland's own state windowed/tiled while telling the game
    -- it IS fullscreen, so it renders correctly instead of letterboxing.
    fullscreen_state = "0 2",
})
