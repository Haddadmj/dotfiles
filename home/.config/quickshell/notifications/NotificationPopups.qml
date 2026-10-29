import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs

// Toasts in the top-right corner, under the bar.
PanelWindow {
    WlrLayershell.namespace: "quickshell:notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    anchors { top: true; right: true }
    margins { top: Theme.gap; right: 20 }
    exclusiveZone: 0
    implicitWidth: 380
    implicitHeight: Math.max(1, stack.implicitHeight)
    color: "transparent"
    visible: Notifs.popups.length > 0 && !Ui.notifCenter && Ui.popup === ""

    ColumnLayout {
        id: stack
        width: parent.width
        spacing: Theme.gap

        Repeater {
            model: ScriptModel { values: Notifs.popups }
            NotificationCard {
                id: card
                required property var modelData
                notif: modelData
                toast: true
                Layout.fillWidth: true

                // slide in from the right
                property real slide: 1
                transform: Translate { x: card.slide * 60 }
                opacity: 1 - card.slide
                Component.onCompleted: slide = 0
                Behavior on slide { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            }
        }
    }
}
