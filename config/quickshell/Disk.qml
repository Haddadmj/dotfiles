import QtQuick
import Quickshell.Io

Text {
    id: root
    property string usage: "--"

    text: "  " + usage + "%"
    color: Colors.text
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 14

    Process {
        id: proc
        command: ["sh", "-c", "df / --output=pcent | tail -1 | tr -d ' %'"]
        stdout: StdioCollector {
            onStreamFinished: root.usage = text.trim()
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: proc.running = true
    }

    Component.onCompleted: proc.running = true
}
