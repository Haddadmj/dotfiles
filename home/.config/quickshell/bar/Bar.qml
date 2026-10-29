import QtQuick
import QtQuick.Layouts
import Quickshell
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

    IdleInhibitor { window: bar; enabled: Ui.keepAwake }

    RowLayout {
        anchors.left: parent.left
        height: parent.height
        spacing: Theme.gap
        LauncherButton {}
        Workspaces {}
        MediaIsland {}
    }

    WindowTitle {
        anchors.centerIn: parent
        maxWidth: bar.width * 0.4
    }

    RowLayout {
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
