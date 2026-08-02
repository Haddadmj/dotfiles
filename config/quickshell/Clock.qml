import QtQuick

Text {
    id: root

    property date now: new Date()

    text: Qt.formatDateTime(now, "hh:mm:ss AP")
    color: Colors.accent
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 14

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }
}
