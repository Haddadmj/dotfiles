pragma Singleton

import QtQuick
import Quickshell

// GENERATED from the current wallpaper by matugen -- do not edit by hand.
// Regenerate with:  wallpaper [/path/to/image]
Singleton {
    // Accent
    // NB: not `onAccent` -- QML reads an `on`-prefixed name as a signal handler.
    readonly property color accent:      "{{colors.primary.default.hex}}"
    readonly property color accentFg:    "{{colors.on_primary.default.hex}}"

    // Surfaces
    readonly property color bg:          "{{colors.surface.default.hex}}"
    readonly property color surface:     "{{colors.surface_container.default.hex}}"
    readonly property color barBg:       "{{colors.surface_container_lowest.default.hex}}"

    // Text
    readonly property color text:        "{{colors.on_surface.default.hex}}"
    readonly property color textDim:     "{{colors.outline.default.hex}}"
    readonly property color textFaint:   Qt.darker(textDim, 1.4)

    // Borders
    readonly property color border:      "{{colors.surface_container_high.default.hex}}"
    readonly property color borderIdle:  "{{colors.outline_variant.default.hex}}"

    // Overlays -- accent-tinted, alpha-prefixed (#AARRGGBB)
    readonly property color hover:       "#22{{colors.primary.default.hex_stripped}}"
    readonly property color hoverStrong: "#33{{colors.primary.default.hex_stripped}}"
    readonly property color scrim:       "#e6{{colors.surface_container_lowest.default.hex_stripped}}"

    // Semantic -- kept distinct from accent so they still read as status
    readonly property color error:       "{{colors.error.default.hex}}"
    readonly property color warning:     "{{colors.tertiary.default.hex}}"
}
