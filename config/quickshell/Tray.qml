import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray

RowLayout {
    id: tray
    spacing: 8

    // Collapse cleanly (no stray parent spacing) when nothing is registered.
    visible: SystemTray.items.values.length > 0

    Repeater {
        model: SystemTray.items

        Item {
            id: entry
            required property var modelData

            Layout.preferredWidth: 16
            Layout.preferredHeight: 16

            Image {
                id: icon
                anchors.fill: parent
                sourceSize.width: 16
                sourceSize.height: 16
                source: entry.modelData.icon
                fillMode: Image.PreserveAspectFit
                smooth: true
                asynchronous: true
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onClicked: mouse => {
                    // Items flagged onlyMenu have no usable activate handler.
                    if (mouse.button === Qt.LeftButton && !entry.modelData.onlyMenu) {
                        entry.modelData.activate();
                    } else if (mouse.button === Qt.MiddleButton) {
                        entry.modelData.secondaryActivate();
                    } else if (entry.modelData.hasMenu) {
                        menuAnchor.open();
                    }
                }
            }

            QsMenuAnchor {
                id: menuAnchor
                menu: entry.modelData.menu
                anchor.item: icon
                anchor.edges: Edges.Bottom
                anchor.gravity: Edges.Bottom
            }
        }
    }
}
