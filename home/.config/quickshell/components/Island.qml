import QtQuick
import QtQuick.Layouts
import qs

// One rounded "island" of the bar. Children go into a centered row.
Rectangle {
    id: root
    default property alias content: row.data
    property int padding: 12
    property alias spacing: row.spacing
    readonly property alias hovered: hover.hovered
    property bool clickable: false
    signal clicked(var mouse)
    signal scrolled(int delta)

    implicitWidth: row.implicitWidth + padding * 2
    implicitHeight: Theme.barHeight
    radius: Theme.radius
    color: Theme.island
    border.width: 1
    border.color: Theme.islandBorder
    clip: true

    Behavior on color { ColorAnimation { duration: Theme.anim } }
    Behavior on implicitWidth { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }

    HoverHandler { id: hover }

    MouseArea {
        anchors.fill: parent
        enabled: root.clickable
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: e => root.clicked(e)
        onWheel: e => root.scrolled(e.angleDelta.y)
    }

    KeyFocus { enabled: root.clickable; onActivated: root.clicked({ button: Qt.LeftButton }) }

    RowLayout {
        id: row
        anchors.centerIn: parent
        height: parent.height
        spacing: 0
    }
}
