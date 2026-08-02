import QtQuick
import Quickshell.Wayland

Text {
    id: root
    required property var barWindow

    IdleInhibitor {
        id: inhibitor
        window: root.barWindow
        enabled: false
    }

    text: inhibitor.enabled ? "󰈈" : "󰈉"
    color: Colors.text
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 14

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: inhibitor.enabled = !inhibitor.enabled
    }
}
