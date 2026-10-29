import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs
import qs.components

// Tray icons hidden behind a chevron; hovering the island slides them out to the left.
Island {
    id: root
    padding: 10
    property int menusOpen: 0
    readonly property bool open: hovered || menusOpen > 0

    // Some apps (Electron, Steam) send "name?path=/dir" instead of an icon name
    function iconSource(icon) {
        if (icon.includes("?path=")) {
            const [name, path] = icon.split("?path=")
            return `file://${path}/${name.slice(name.lastIndexOf("/") + 1)}`
        }
        return icon
    }

    Item {
        Layout.preferredWidth: root.open ? tray.implicitWidth + 10 : 0
        Layout.preferredHeight: Theme.barHeight
        clip: true
        Behavior on Layout.preferredWidth { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

        Row {
            id: tray
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 10
            spacing: 10
            opacity: root.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 300 } }

            Repeater {
                model: SystemTray.items

                MouseArea {
                    id: item
                    required property SystemTrayItem modelData
                    width: 16
                    height: 16
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor

                    IconImage {
                        anchors.fill: parent
                        source: root.iconSource(item.modelData.icon)
                        opacity: item.modelData.status === Status.Passive ? 0.55 : 1
                    }

                    onClicked: e => {
                        const t = item.modelData
                        if (e.button === Qt.MiddleButton) t.secondaryActivate()
                        else if (e.button === Qt.RightButton || t.onlyMenu) { if (t.hasMenu) menu.open() }
                        else t.activate()
                    }
                    onWheel: e => item.modelData.scroll(e.angleDelta.y, false)

                    QsMenuAnchor {
                        id: menu
                        menu: item.modelData.menu
                        anchor.item: item
                        anchor.rect.y: item.height + 16
                        onVisibleChanged: root.menusOpen += visible ? 1 : -1
                    }

                    Tip {
                        target: item
                        show: item.containsMouse && !menu.visible
                        text: item.modelData.tooltipTitle || item.modelData.title || item.modelData.id
                    }
                }
            }
        }
    }

    T {
        text: Icons.chevronLeft
        color: Theme.primary
        font.pixelSize: 15
        rotation: root.open ? 180 : 0
        Behavior on rotation { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
    }
}
