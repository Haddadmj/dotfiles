import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs
import qs.components

// Workspaces 1-5 always shown (shell · web · code · chat · media), others while they exist.
Island {
    id: root
    padding: 4

    readonly property var ids: {
        const s = new Set([1, 2, 3, 4, 5])
        for (const w of Hyprland.workspaces.values) if (w.id > 0) s.add(w.id)
        return [...s].sort((a, b) => a - b)
    }

    function goTo(ws) { Hyprland.dispatch(`hl.dsp.focus({ workspace = "${ws}" })`) }

    Repeater {
        model: root.ids

        Rectangle {
            id: btn
            required property int modelData
            readonly property var ws: Hyprland.workspaces.values.find(w => w.id === modelData) ?? null
            readonly property bool active: Hyprland.focusedWorkspace?.id === modelData
            readonly property bool empty: !ws || ws.toplevels.values.length === 0
            readonly property bool urgent: ws?.urgent ?? false

            Layout.preferredHeight: Theme.barHeight - 10
            Layout.preferredWidth: label.implicitWidth + (active ? 40 : 20)
            Layout.leftMargin: 2
            Layout.rightMargin: 2
            radius: 7
            color: urgent ? Theme.error
                 : active ? Theme.primary
                 : mouse.containsMouse ? Theme.alpha(Theme.secondary, 0.9) : Theme.alpha(Theme.secondary, 0)

            Behavior on Layout.preferredWidth { NumberAnimation { duration: 350; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
            Behavior on color { ColorAnimation { duration: 250 } }

            T {
                id: label
                anchors.centerIn: parent
                text: btn.urgent ? Icons.wsUrgent : (Icons.workspaces[btn.modelData] ?? Icons.wsDefault)
                font.family: btn.modelData === 2 && !btn.urgent ? "Font Awesome 7 Brands" : Theme.font
                font.pixelSize: 15
                color: btn.urgent ? Theme.errorText
                     : btn.active ? Theme.primaryText
                     : mouse.containsMouse ? Theme.fg
                     : Theme.alpha(Theme.fg, btn.empty ? 0.3 : 0.75)
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.goTo(btn.modelData)
            }
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: e => root.goTo(e.angleDelta.y > 0 ? "e-1" : "e+1")
    }
}
