import QtQuick
import qs

// Single-line text input with a placeholder. Emits accepted() on Enter.
Rectangle {
    id: root
    property alias text: input.text
    property string placeholder: ""
    property bool invalid: false
    signal accepted()
    signal escaped()

    implicitWidth: 200
    implicitHeight: 30
    radius: 7
    color: Theme.alpha(Theme.secondary, 0.5)
    border.width: 1
    border.color: invalid ? Theme.error : input.activeFocus ? Theme.alpha(Theme.primary, 0.7) : "transparent"

    function takeFocus() { input.forceActiveFocus() }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        color: Theme.fg
        font.family: Theme.font
        font.pixelSize: 12
        selectionColor: Theme.primary
        selectedTextColor: Theme.primaryText
        onAccepted: root.accepted()
        Keys.onEscapePressed: root.escaped()
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        x: 10
        visible: input.text === "" && !input.activeFocus
        text: root.placeholder
        color: Theme.alpha(Theme.fg, 0.35)
        font.family: Theme.font
        font.pixelSize: 12
    }
}
