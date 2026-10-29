import QtQuick
import qs

// Small rounded button: icon and/or text. `on` highlights it, `danger` hovers red.
Rectangle {
    id: root
    property string icon: ""
    property string text: ""
    property bool on: false
    property bool danger: false
    signal clicked()
    implicitWidth: label.implicitWidth + 18
    implicitHeight: 26
    radius: 7
    color: on ? Theme.primary
       : mouse.containsMouse ? (danger ? Theme.error : Theme.alpha(Theme.secondary, 0.95))
       : Theme.alpha(Theme.secondary, 0.5)
    Behavior on color { ColorAnimation { duration: 150 } }
    T {
        id: label
        anchors.centerIn: parent
        text: [root.icon, root.text].filter(s => s).join("  ")
        font.pixelSize: 12
        color: root.on ? Theme.primaryText : mouse.containsMouse && root.danger ? Theme.errorText : Theme.fg
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
