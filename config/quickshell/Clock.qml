import QtQuick

Text {
    id: root
    required property var barWindow

    property date now: new Date()

    text: Qt.formatDateTime(now, "hh:mm:ss AP  ·  dd/MM/yyyy")
    color: Colors.accent
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 14

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            // Hand the popup our centre in screen coordinates so it drops
            // straight under the clock. mapToItem(null, ...) is relative to the
            // bar window, which the compositor has inset by the bar's margin.
            const p = root.mapToItem(null, root.width / 2, 0);
            CalendarState.toggle(root.barWindow.screen,
                                 p.x + root.barWindow.margins.left);
        }
    }
}
