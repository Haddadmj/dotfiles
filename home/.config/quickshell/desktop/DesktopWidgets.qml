import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs

// Widgets on the wallpaper, under all windows: a big clock. Fully click-through.
PanelWindow {
    id: root
    required property var modelData
    screen: modelData

    WlrLayershell.namespace: "quickshell:desktop"
    WlrLayershell.layer: WlrLayer.Bottom
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    mask: Region {}

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // clock: soft shadow so it reads on any wallpaper
    ColumnLayout {
        anchors.left: parent.left
        anchors.leftMargin: 70
        y: Theme.gap + Theme.barHeight + 60
        spacing: -6

        Text {
            text: Qt.formatTime(clock.date, "hh:mm")
            font.family: Theme.font
            font.pixelSize: 110
            font.weight: Font.Bold
            color: Theme.alpha(Theme.fg, 0.9)
            style: Text.Raised
            styleColor: Theme.alpha(Theme.bg, 0.5)
        }
        Text {
            Layout.leftMargin: 6
            text: Qt.formatDate(clock.date, "dddd, d MMMM")
            font.family: Theme.font
            font.pixelSize: 24
            color: Theme.alpha(Theme.primary, 0.95)
            style: Text.Raised
            styleColor: Theme.alpha(Theme.bg, 0.5)
        }
    }
}
