import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components

// Side panel with every notification, do-not-disturb and clear-all. Toggle: bell, SUPER+N.
PanelWindow {
    id: root
    readonly property bool open: Ui.notifCenter

    WlrLayershell.namespace: "quickshell:notifcenter"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    anchors { top: true; right: true; bottom: true }
    margins { top: Theme.gap; right: 20; bottom: 20 }
    exclusiveZone: 0
    implicitWidth: 410
    color: "transparent"
    visible: false

    onOpenChanged: {
        if (open) { hideTimer.stop(); visible = true }
        else hideTimer.restart()
    }
    Timer { id: hideTimer; interval: Theme.anim; onTriggered: root.visible = false }

    HyprlandFocusGrab {
        active: root.open
        windows: [root]
        onCleared: Ui.notifCenter = false
    }

    Rectangle {
        id: panel
        anchors.fill: parent
        radius: Theme.radius + 4
        color: Theme.popup
        border.width: 1
        border.color: Theme.alpha(Theme.primary, 0.35)
        opacity: root.open ? 1 : 0
        transform: Translate { x: root.open ? 0 : 40; Behavior on x { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } } }
        Behavior on opacity { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }

        focus: root.open
        Keys.onEscapePressed: Ui.notifCenter = false
        Keys.onDownPressed: nextItemInFocusChain(true).forceActiveFocus()
        Keys.onUpPressed: nextItemInFocusChain(false).forceActiveFocus()

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                T { text: "Notifications"; font.pixelSize: 16; Layout.fillWidth: true }

                component HeaderButton: Rectangle {
                    id: hb
                    property string icon
                    property string label
                    property bool on: false
                    signal clicked()
                    implicitWidth: hbRow.implicitWidth + 20
                    implicitHeight: 30
                    radius: 8
                    color: on ? Theme.primary : hbMouse.containsMouse ? Theme.secondary : Theme.alpha(Theme.secondary, 0.5)
                    Behavior on color { ColorAnimation { duration: 150 } }
                    RowLayout {
                        id: hbRow
                        anchors.centerIn: parent
                        spacing: 6
                        T { text: hb.icon; color: hb.on ? Theme.primaryText : Theme.fg }
                        T { text: hb.label; color: hb.on ? Theme.primaryText : Theme.fg; font.pixelSize: 12 }
                    }
                    MouseArea { id: hbMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: hb.clicked() }
                    KeyFocus { onActivated: hb.clicked() }
                }

                HeaderButton { icon: Notifs.dnd ? Icons.bellOff : Icons.bell; label: "Do not disturb"; on: Notifs.dnd; onClicked: Notifs.dnd = !Notifs.dnd }
                HeaderButton { icon: Icons.trash; label: "Clear"; visible: Notifs.count > 0; onClicked: Notifs.clear() }
            }

            ListView {
                id: notifList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Theme.gap
                model: ScriptModel { values: Notifs.list }
                boundsBehavior: Flickable.StopAtBounds
                WheelScroll { view: notifList }

                delegate: NotificationCard {
                    required property var modelData
                    notif: modelData
                    width: ListView.view.width
                }

                add: Transition { NumberAnimation { properties: "opacity"; from: 0; to: 1; duration: 200 } }
                remove: Transition { NumberAnimation { properties: "opacity"; to: 0; duration: 200 } }
                displaced: Transition { NumberAnimation { properties: "y"; duration: 200; easing.type: Easing.OutCubic } }

                T {
                    anchors.centerIn: parent
                    visible: Notifs.count === 0
                    text: `${Icons.bell}\n\nNo notifications`
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.alpha(Theme.fg, 0.4)
                    font.pixelSize: 14
                }
            }
        }
    }
}
