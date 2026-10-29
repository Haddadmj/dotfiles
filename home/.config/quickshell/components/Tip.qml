import QtQuick
import Quickshell
import qs

// Tooltip under `target`, shown after a short hover. Supports StyledText (<b>, <br>, <font>).
PopupWindow {
    id: root
    required property Item target
    property bool show: false
    property string text: ""
    property bool shown: false

    anchor.item: target
    anchor.rect.x: (target.width - width) / 2
    anchor.rect.y: target.height + 12
    implicitWidth: label.implicitWidth + 22
    implicitHeight: label.implicitHeight + 14
    color: "transparent"
    visible: shown && text !== "" && Ui.popup === ""

    onShowChanged: {
        if (show) delay.restart()
        else { delay.stop(); shown = false }
    }
    Timer { id: delay; interval: 450; onTriggered: root.shown = true }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.popup
        border.width: 1
        border.color: Theme.alpha(Theme.primary, 0.4)

        Text {
            id: label
            anchors.centerIn: parent
            text: root.text
            textFormat: Text.StyledText
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
            lineHeight: 1.15
        }
    }
}
