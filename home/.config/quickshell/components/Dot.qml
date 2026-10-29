import QtQuick
import qs

// "Changed from the default" marker; click it to reset.
Rectangle {
    id: root
    property bool modified: false
    signal reset()
    implicitWidth: 8; implicitHeight: 8; radius: 4
    color: modified ? Theme.primary : "transparent"
    MouseArea {
        anchors.fill: parent
        anchors.margins: -6
        enabled: root.modified
        cursorShape: Qt.PointingHandCursor
        onClicked: root.reset()
    }
}
