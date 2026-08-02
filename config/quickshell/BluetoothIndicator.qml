import QtQuick
import Quickshell
import Quickshell.Bluetooth

Text {
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool anyConnected: {
        for (const d of Bluetooth.devices.values) {
            if (d.connected) return true;
        }
        return false;
    }

    text: (!adapter || !adapter.powered) ? "󰂲" : (anyConnected ? "󰂴" : "")
    color: Colors.text
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 14

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["rofi-bluetooth"])
    }
}
