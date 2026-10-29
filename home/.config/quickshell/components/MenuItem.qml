import QtQuick
import QtQuick.Layouts
import qs

// A row in a popup menu: icon + label, highlighted on hover.
Rectangle {
    id: root
    property string icon: ""
    property string text: ""
    property color hoverColor: Theme.primary
    property color hoverText: Theme.primaryText
    property bool active: false
    signal clicked()

    Layout.fillWidth: true
    implicitWidth: row.implicitWidth + 28
    implicitHeight: 34
    radius: 7
    color: mouse.containsMouse ? hoverColor : active ? Theme.alpha(Theme.primary, 0.15) : "transparent"
    Behavior on color { ColorAnimation { duration: 150 } }

    RowLayout {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.rightMargin: 14
        spacing: 12
        T { text: root.icon; font.pixelSize: 15; color: mouse.containsMouse ? root.hoverText : root.active ? Theme.primary : Theme.fg; visible: text !== "" }
        T { text: root.text; Layout.fillWidth: true; elide: Text.ElideRight; color: mouse.containsMouse ? root.hoverText : root.active ? Theme.primary : Theme.fg }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
