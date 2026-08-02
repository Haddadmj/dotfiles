import QtQuick
import Quickshell
import Quickshell.Io

Text {
    id: root
    property string connType: ""

    text: connType === "wifi" ? " " : connType === "ethernet" ? " " : ""
    color: Colors.text
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 14

    Process {
        id: proc
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE device status | awk -F: '$2==\"connected\" && ($1==\"wifi\"||$1==\"ethernet\") {print $1; exit}'"]
        stdout: StdioCollector {
            onStreamFinished: root.connType = text.trim()
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: proc.running = true
    }

    Component.onCompleted: proc.running = true

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["networkmanager_dmenu"])
    }
}
