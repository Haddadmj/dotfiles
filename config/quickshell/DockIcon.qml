import QtQuick
import Quickshell
import Quickshell.Hyprland

Item {
    id: root
    required property var appData
    required property var dockWindow

    width: 44
    height: 44

    // Keep the dock from auto-hiding while this icon is in use.
    Component.onDestruction: {
        if (hoverArea.containsMouse) root.dockWindow.hoverCount--;
        if (quitMenu.visible) root.dockWindow.holdCount--;
    }

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: hoverArea.containsMouse ? Colors.hoverStrong : "transparent"

        Behavior on color {
            ColorAnimation { duration: 100 }
        }
    }

    Image {
        visible: !!root.appData.icon
        anchors.centerIn: parent
        width: 32
        height: 32
        source: root.appData.icon || ""
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
    }

    Text {
        visible: !root.appData.icon && !!root.appData.glyph
        anchors.centerIn: parent
        text: root.appData.glyph || ""
        color: Colors.text
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 20
    }

    Rectangle {
        visible: root.appData.running
        width: 5
        height: 5
        radius: 2.5
        color: Colors.accent
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onContainsMouseChanged: root.dockWindow.hoverCount += containsMouse ? 1 : -1
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                if (root.appData.launchNew) root.appData.launchNew();
            } else if (mouse.button === Qt.RightButton) {
                const tops = root.appData.toplevels;
                if (tops && tops.length > 0) {
                    const point = root.mapToItem(root.dockWindow.contentItem, 0, 0);
                    quitMenu.menuX = point.x + root.width / 2 - quitMenu.implicitWidth / 2;
                    quitMenu.menuY = point.y - quitMenu.implicitHeight - 8;
                    quitMenu.visible = true;
                }
            } else {
                root.appData.activate();
            }
        }
    }

    PopupWindow {
        id: quitMenu

        readonly property var tops: root.appData.toplevels || []
        readonly property bool multiple: tops.length > 1
        property real menuX: 0
        property real menuY: 0

        anchor.window: root.dockWindow
        anchor.rect.x: menuX
        anchor.rect.y: menuY
        implicitWidth: 200
        implicitHeight: menuColumn.implicitHeight
        visible: false
        color: "transparent"

        onVisibleChanged: root.dockWindow.holdCount += visible ? 1 : -1

        HyprlandFocusGrab {
            id: grab
            windows: [quitMenu]
            active: quitMenu.visible
            onCleared: quitMenu.visible = false
        }

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: Colors.barBg

            Column {
                id: menuColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                padding: 6

                Repeater {
                    model: quitMenu.tops.length

                    Rectangle {
                        required property int index

                        width: menuColumn.width - 12
                        height: 28
                        radius: 6
                        color: quitRowArea.containsMouse ? Colors.hoverStrong : "transparent"

                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            text: quitMenu.multiple ? quitMenu.tops[index].title : "Quit"
                            color: Colors.text
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            id: quitRowArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                quitMenu.tops[index].close();
                                quitMenu.visible = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
