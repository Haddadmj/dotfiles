import QtQuick
import qs

// Thin horizontal slider (0..max). Emits moved(value) while dragging / scrolling.
Item {
    id: root
    property real value: 0
    property real max: 1
    property color accent: Theme.primary
    signal moved(real value)

    implicitHeight: 18
    implicitWidth: 200

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: Theme.alpha(Theme.fg, 0.15)

        Rectangle {
            width: Math.max(height, Math.min(1, root.value / root.max) * parent.width)
            height: parent.height
            radius: 3
            color: root.accent
            Behavior on width { enabled: !mouse.pressed; NumberAnimation { duration: 120 } }
        }
    }
    Rectangle {
        x: Math.min(1, root.value / root.max) * (root.width - width)
        anchors.verticalCenter: parent.verticalCenter
        width: 14; height: 14; radius: 7
        color: root.accent
        border.width: 3
        border.color: Theme.bg
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function set(x) { root.moved(Math.max(0, Math.min(1, x / width)) * root.max) }
        onPressed: e => set(e.x)
        onPositionChanged: e => { if (pressed) set(e.x) }
        onWheel: e => root.moved(Math.max(0, Math.min(root.max, root.value + (e.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
