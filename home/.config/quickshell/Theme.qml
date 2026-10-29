pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Colors come from matugen → colors.json (template: ~/.config/hypr/matugen/templates/quickshell-colors.json).
// The file is watched, so a new wallpaper recolors the shell live.
Singleton {
    readonly property color bg: json.bg
    readonly property color fg: json.fg
    readonly property color fgDim: json.fgDim
    readonly property color primary: json.primary
    readonly property color primaryText: json.primaryText
    readonly property color primaryC: json.primaryC
    readonly property color primaryCText: json.primaryCText
    readonly property color secondary: json.secondary
    readonly property color secondaryText: json.secondaryText
    readonly property color tertiary: json.tertiary
    readonly property color tertiaryText: json.tertiaryText
    readonly property color error: json.error
    readonly property color errorText: json.errorText
    readonly property color outline: json.outline
    readonly property color surfaceHigh: json.surfaceHigh

    readonly property color island: alpha(bg, 0.75)
    readonly property color islandBorder: alpha(outline, 0.8)
    readonly property color popup: alpha(bg, 0.94)

    readonly property string font: "JetBrainsMono Nerd Font Propo"
    readonly property int fontSize: 13
    readonly property int barHeight: 38
    readonly property int gap: 8
    readonly property int radius: 10
    readonly property int anim: 250

    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    function mix(a, b, t) { return Qt.tint(a, alpha(b, t)) }

    FileView {
        path: Quickshell.shellPath("colors.json")
        watchChanges: true
        onFileChanged: reload()

        adapter: JsonAdapter {
            id: json
            property string bg: "#101417"
            property string fg: "#e0e3e8"
            property string fgDim: "#c1c7ce"
            property string primary: "#95cdf7"
            property string primaryText: "#00344e"
            property string primaryC: "#004b6f"
            property string primaryCText: "#c9e6ff"
            property string secondary: "#384956"
            property string secondaryText: "#d3e5f5"
            property string tertiary: "#cfc0e8"
            property string tertiaryText: "#352b4b"
            property string error: "#ffb4ab"
            property string errorText: "#690005"
            property string outline: "#41474d"
            property string surfaceHigh: "#262a2e"
        }
    }
}
