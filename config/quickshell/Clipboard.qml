import QtQuick
import Quickshell

Text {
    text: ""
    color: Colors.text
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 14

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["sh", "-c", "cliphist list | rofi -dmenu | cliphist decode | wl-copy"])
    }
}
