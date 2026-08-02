pragma Singleton

import QtQuick
import Quickshell

// GENERATED from the current wallpaper by matugen -- do not edit by hand.
// Regenerate with:  wallpaper [/path/to/image]
Singleton {
    // Accent
    // NB: not `onAccent` -- QML reads an `on`-prefixed name as a signal handler.
    readonly property color accent:      "#b1c6ff"
    readonly property color accentFg:    "#162e60"

    // Surfaces
    readonly property color bg:          "#121318"
    readonly property color surface:     "#1e1f25"
    readonly property color barBg:       "#0c0e13"

    // Text
    readonly property color text:        "#e2e2e9"
    readonly property color textDim:     "#8f9099"
    readonly property color textFaint:   Qt.darker(textDim, 1.4)

    // Borders
    readonly property color border:      "#282a2f"
    readonly property color borderIdle:  "#44464f"

    // Overlays -- accent-tinted, alpha-prefixed (#AARRGGBB)
    readonly property color hover:       "#22b1c6ff"
    readonly property color hoverStrong: "#33b1c6ff"
    readonly property color scrim:       "#e60c0e13"

    // Semantic -- kept distinct from accent so they still read as status
    readonly property color error:       "#ffb4ab"
    readonly property color warning:     "#e0bbdd"
}
