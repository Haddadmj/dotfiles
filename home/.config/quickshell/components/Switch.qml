import QtQuick
import qs

// On/off switch. Emits toggled(); the owner flips `checked`.
Rectangle {
    id: sw
    property bool checked
    signal toggled()
    implicitWidth: 40; implicitHeight: 22; radius: 11
    color: checked ? Theme.primary : Theme.alpha(Theme.fg, 0.15)
    Behavior on color { ColorAnimation { duration: 150 } }
    Rectangle {
        x: sw.checked ? sw.width - width - 3 : 3
        anchors.verticalCenter: parent.verticalCenter
        width: 16; height: 16; radius: 8
        color: sw.checked ? Theme.primaryText : Theme.fg
        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sw.toggled() }
}
