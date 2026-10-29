import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs
import qs.components

// Workspaces that have an app rule in hypr/modules/rules.lua (workspace = "N") are always shown,
// others only while focused. Re-read when rules.lua changes.
Island {
    id: root
    padding: 4

    FileView {
        id: rules
        path: Quickshell.env("HOME") + "/.config/hypr/modules/rules.lua"
        watchChanges: true
        onFileChanged: reload()
    }
    readonly property var ruled: (rules.text().match(/^\s*workspace\s*=\s*"\d+"/gm) ?? []).map(l => +l.match(/\d+/)[0])

    readonly property var ids: {
        const s = new Set(ruled)
        const cur = Hyprland.focusedWorkspace?.id ?? 0
        if (cur > 0) s.add(cur)
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

    // Wheel steps through every workspace shown in the bar (empty ones too), wrapping at the ends.
    // Deltas accumulate so one wheel notch / one touchpad swipe = one step, not a burst.
    property real wheelAcc: 0
    function step(dir) {
        const i = ids.indexOf(Hyprland.focusedWorkspace?.id ?? 1)
        goTo(ids[(i + dir + ids.length) % ids.length])
    }
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: e => {
            const d = e.angleDelta.y
            if (d === 0) return
            if (Math.sign(d) !== Math.sign(root.wheelAcc)) root.wheelAcc = 0
            root.wheelAcc += d
            if (Math.abs(root.wheelAcc) < 120 || wheelCooldown.running) return
            root.step(root.wheelAcc > 0 ? -1 : 1)
            root.wheelAcc = 0
            wheelCooldown.restart()
        }
    }
    Timer { id: wheelCooldown; interval: 180 }
}
