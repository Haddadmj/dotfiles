import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs

// Floating islands bar. The window itself is transparent; only the islands are drawn.
PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    WlrLayershell.namespace: "quickshell:bar"
    anchors { top: true; left: true; right: true }
    margins { top: Theme.gap; left: 20; right: 20 }
    implicitHeight: Theme.barHeight
    color: "transparent"
    readonly property bool keys: Ui.barKeys && modelData.name === Hyprland.focusedMonitor?.name
    WlrLayershell.keyboardFocus: keys ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    onKeysChanged: if (keys) nav.nextItemInFocusChain(true).forceActiveFocus()

    IdleInhibitor { window: bar; enabled: Ui.keepAwake }

    FocusScope {
    id: nav
    anchors.fill: parent
    Keys.onEscapePressed: Ui.barKeys = false

    RowLayout {
        id: leftRow
        anchors.left: parent.left
        height: parent.height
        spacing: Theme.gap
        LauncherButton {}
        Workspaces {}
    }

    // centered when it fits, otherwise slides left and shrinks so it never covers the right islands
    WindowTitle {
        readonly property real lo: leftRow.width + Theme.gap
        readonly property real hi: bar.width - rightRow.width - Theme.gap
        anchors.verticalCenter: parent.verticalCenter
        maxWidth: Math.max(0, Math.min(bar.width * 0.4, hi - lo))
        x: Math.max(lo, Math.min((bar.width - width) / 2, hi - width))
    }

    RowLayout {
        id: rightRow
        anchors.right: parent.right
        height: parent.height
        spacing: Theme.gap
        Privacy {}
        SysMon {}
        Devices {}
        TrayDrawer {}
        SystemIsland {}
        Language {}
        Audio {}
        Clock {}
        QuickSettingsButton {}
        Power {}
    }
    }
}
