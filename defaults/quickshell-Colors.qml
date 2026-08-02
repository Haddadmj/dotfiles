pragma Singleton

import QtQuick
import Quickshell

// NEUTRAL FALLBACK -- seeded by install.sh only when no themed file exists.
// Regenerate with:  wallpaper [/path/to/image]
Singleton {
    // Accent
    // NB: not `onAccent` -- QML reads an `on`-prefixed name as a signal handler.
    readonly property color accent:      "#9db4c8"
    readonly property color accentFg:    "#16242c"

    // Surfaces
    readonly property color bg:          "#131416"
    readonly property color surface:     "#1d1f22"
    readonly property color barBg:       "#0b0c0e"

    // Text
    readonly property color text:        "#e3e4e6"
    readonly property color textDim:     "#909398"
    readonly property color textFaint:   Qt.darker(textDim, 1.4)

    // Borders
    readonly property color border:      "#2a2c30"
    readonly property color borderIdle:  "#4a4d52"

    // Overlays -- accent-tinted, alpha-prefixed (#AARRGGBB)
    readonly property color hover:       "#229db4c8"
    readonly property color hoverStrong: "#339db4c8"
    readonly property color scrim:       "#e60b0c0e"

    // Semantic -- kept distinct from accent so they still read as status
    readonly property color error:       "#ffb4ab"
    readonly property color warning:     "#e6c07b"
}
