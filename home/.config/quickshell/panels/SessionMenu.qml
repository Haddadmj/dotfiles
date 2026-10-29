import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components

// Session menu (SUPER+M), wlogout style: lock, log out, suspend, reboot, shut down.
// Keys: ←/→ or Tab move · Enter run · L E U R S shortcuts · Esc close.
PanelWindow {
    id: root
    readonly property bool open: Ui.session
    property int current: 0

    readonly property var actions: [
        { icon: Icons.lock,     label: "Lock",      key: "L", cmd: "loginctl lock-session" },
        { icon: Icons.logout,   label: "Log out",   key: "E", cmd: "command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'" },
        { icon: Icons.suspend,  label: "Suspend",   key: "U", cmd: "systemctl suspend" },
        { icon: Icons.reboot,   label: "Reboot",    key: "R", cmd: "systemctl reboot" },
        { icon: Icons.shutdown, label: "Shut down", key: "S", cmd: "systemctl poweroff" },
    ]

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    WlrLayershell.namespace: "quickshell:session"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: false

    onOpenChanged: {
        if (open) { hideTimer.stop(); current = 0; visible = true; content.forceActiveFocus() }
        else hideTimer.restart()
    }
    Timer { id: hideTimer; interval: Theme.anim; onTriggered: root.visible = false }

    // close first so the lock screen / shutdown doesn't race the fade-out
    function run(i) {
        Ui.session = false
        Quickshell.execDetached(["sh", "-c", `sleep 0.2; ${actions[i].cmd}`])
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.bg, 0.6)
        opacity: root.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent; onClicked: Ui.session = false }
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }

        Keys.onPressed: e => {
            const n = root.actions.length
            const hit = root.actions.findIndex(a => e.text.toUpperCase() === a.key)
            if (e.key === Qt.Key_Escape) Ui.session = false
            else if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab) root.current = (root.current + 1) % n
            else if (e.key === Qt.Key_Left || e.key === Qt.Key_Backtab) root.current = (root.current + n - 1) % n
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) root.run(root.current)
            else if (hit >= 0) root.run(hit)
            else return
            e.accepted = true
        }

        RowLayout {
            anchors.centerIn: parent
            spacing: 20

            Repeater {
                model: root.actions
                Rectangle {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property bool on: root.current === index
                    readonly property bool danger: index >= 3
                    implicitWidth: 170
                    implicitHeight: 190
                    radius: Theme.radius + 6
                    color: on ? (danger ? Theme.error : Theme.primary) : Theme.alpha(Theme.popup, 0.85)
                    border.width: 1
                    border.color: Theme.alpha(Theme.primary, 0.35)
                    Behavior on color { ColorAnimation { duration: 150 } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 14
                        T {
                            Layout.alignment: Qt.AlignHCenter
                            text: tile.modelData.icon
                            font.pixelSize: 56
                            color: tile.on ? (tile.danger ? Theme.errorText : Theme.primaryText) : Theme.fg
                        }
                        T {
                            Layout.alignment: Qt.AlignHCenter
                            text: tile.modelData.label
                            font.pixelSize: 16
                            color: tile.on ? (tile.danger ? Theme.errorText : Theme.primaryText) : Theme.fg
                        }
                    }
                    T {
                        anchors { top: parent.top; right: parent.right; margins: 10 }
                        text: tile.modelData.key
                        font.pixelSize: 11
                        color: Theme.alpha(tile.on ? (tile.danger ? Theme.errorText : Theme.primaryText) : Theme.fg, 0.5)
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.current = tile.index
                        onClicked: root.run(tile.index)
                    }
                }
            }
        }
    }
}
