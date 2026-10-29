import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs

// Dropdown panel attached to a bar island. Only one is open at a time (Ui.popup).
// Clicking outside or pressing Escape closes it.
PopupWindow {
    id: root
    required property Item target
    required property string name
    property real align: 0.5          // 0 = left edges line up, 1 = right edges line up
    property int padding: 12
    property bool above: false        // open upwards (dock) instead of below the bar
    default property alias content: body.data
    readonly property bool open: Ui.popup === name

    anchor.item: target
    anchor.rect.x: (target.width - width) * align
    anchor.rect.y: above ? -height - 8 : target.height + 6
    implicitWidth: body.implicitWidth + padding * 2
    implicitHeight: body.implicitHeight + padding * 2
    color: "transparent"
    visible: false

    onOpenChanged: {
        if (open) { hideTimer.stop(); visible = true }
        else hideTimer.restart()
    }
    Timer { id: hideTimer; interval: Theme.anim; onTriggered: root.visible = false }

    HyprlandFocusGrab {
        active: root.open
        windows: [root, root.target.QsWindow.window]
        onCleared: if (Ui.popup === root.name) Ui.popup = ""
    }

    Rectangle {
        id: panel
        anchors.fill: parent
        radius: Theme.radius + 2
        color: Theme.popup
        border.width: 1
        border.color: Theme.alpha(Theme.primary, 0.35)
        opacity: root.open ? 1 : 0
        transform: Translate { y: root.open ? 0 : root.above ? 10 : -10; Behavior on y { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } } }
        Behavior on opacity { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }

        focus: root.open
        Keys.onEscapePressed: Ui.popup = ""

        ColumnLayout {
            id: body
            anchors.fill: parent
            anchors.margins: root.padding
            spacing: 6
        }
    }
}
