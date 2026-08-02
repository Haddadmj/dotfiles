---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "us,ara",
        kb_variant = "",
        kb_model   = "",
        -- Switch layout with Alt+Shift; right alt stays a plain modifier (no 3rd-level/AltGr)
        kb_options = "grp:alt_shift_toggle,lv3:ralt_alt",
        kb_rules   = "",

        repeat_rate = 25,
        repeat_delay = 300,

        follow_mouse = 1,

        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})

-- Example per-device config
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/ for more
hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
    scroll_factor = 0.2
})
