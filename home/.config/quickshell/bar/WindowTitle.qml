import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs
import qs.components

// Active window: app icon + title. Hidden on an empty workspace.
Island {
    id: root
    property real maxWidth: 700
    padding: 16
    spacing: 8

    readonly property var toplevel: Hyprland.activeToplevel
    readonly property bool hasWindow: toplevel !== null && (Hyprland.focusedWorkspace?.toplevels.values.length ?? 0) > 0
    readonly property string appId: toplevel?.wayland?.appId ?? toplevel?.lastIpcObject?.class ?? ""
    readonly property string title: rewrite(toplevel?.title ?? "")
    readonly property string icon: {
        const e = appId ? DesktopEntries.heuristicLookup(appId) : null
        return Quickshell.iconPath(e?.icon ?? appId, true)
    }

    // same rewrites as the Waybar config
    function rewrite(t) {
        return t.replace(/ — Mozilla Firefox$/, "")
                .replace(/ - Brave.*$/, "")
                .replace(/ - Visual Studio Code$/, "")
    }

    opacity: hasWindow && title !== "" ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Theme.anim } }

    IconImage {
        source: root.icon
        implicitSize: 16
        visible: root.icon !== ""
    }
    T {
        text: root.title
        elide: Text.ElideRight
        Layout.maximumWidth: root.maxWidth
    }
}
