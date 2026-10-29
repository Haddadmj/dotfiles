import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components

// Applications folder: every app in a searchable grid.
// Click launches · right-click keeps it in / removes it from the dock · type to filter · Enter launches the first match.
ColumnLayout {
    id: root
    property bool open: false
    readonly property int columns: 6
    readonly property int cell: 104
    spacing: 10

    onOpenChanged: if (open) { search.text = ""; grid.positionViewAtBeginning(); search.forceActiveFocus() }

    readonly property var apps: {
        const q = search.text.trim().toLowerCase()
        return DesktopEntries.applications.values
            .filter(a => !a.noDisplay)
            .filter(a => !q || `${a.name} ${a.genericName} ${a.keywords.join(" ")}`.toLowerCase().includes(q))
            .sort((a, b) => a.name.localeCompare(b.name))
    }

    function launch(a) { Dock.launch(a.id); Ui.popup = "" }

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 40
        spacing: 10

        T { text: Icons.apps; color: Theme.primary; font.pixelSize: 18; Layout.leftMargin: 4 }
        T { text: "Applications"; font.pixelSize: 15 }
        Item { Layout.fillWidth: true }

        Rectangle {
            Layout.preferredWidth: 240
            Layout.preferredHeight: 34
            radius: Theme.radius
            color: Theme.alpha(Theme.secondary, 0.6)
            border.width: 1
            border.color: search.activeFocus ? Theme.alpha(Theme.primary, 0.6) : "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8
                T { text: Icons.search; color: Theme.primary }
                TextInput {
                    id: search
                    Layout.fillWidth: true
                    color: Theme.fg
                    selectionColor: Theme.primary
                    selectedTextColor: Theme.primaryText
                    font.family: Theme.font
                    font.pixelSize: 13
                    clip: true
                    Keys.onReturnPressed: if (root.apps.length) root.launch(root.apps[0])
                    Keys.onEnterPressed: if (root.apps.length) root.launch(root.apps[0])
                    T {
                        visible: !search.text
                        text: "Search…"
                        color: Theme.alpha(Theme.fg, 0.4)
                        font.weight: Font.Normal
                    }
                }
            }
        }
    }

    GridView {
        id: grid
        Layout.preferredWidth: root.columns * root.cell
        Layout.preferredHeight: root.cell * 4.5
        cellWidth: root.cell
        cellHeight: root.cell
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: ScriptModel { values: root.apps }
        WheelScroll { view: grid }

        delegate: Item {
            id: tile
            required property var modelData
            readonly property bool pinned: Dock.pinned.includes(modelData.id)
            width: root.cell
            height: root.cell

            Rectangle {
                anchors.fill: parent
                anchors.margins: 3
                radius: Theme.radius
                color: tm.containsMouse ? Theme.alpha(Theme.primary, 0.18) : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - 14
                spacing: 6
                AppIcon {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 52
                    Layout.preferredHeight: 52
                    icon: tile.modelData.icon
                    sourceSize: Qt.size(104, 104)
                    asynchronous: true
                }
                T {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: tile.modelData.name
                    elide: Text.ElideRight
                    font.pixelSize: 11
                    font.weight: Font.Medium
                }
            }

            // in the dock already
            Rectangle {
                visible: tile.pinned
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 12
                width: 8
                height: 8
                radius: 4
                color: Theme.primary
            }

            MouseArea {
                id: tm
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: e => e.button === Qt.RightButton ? Dock.togglePin(tile.modelData.id) : root.launch(tile.modelData)
            }
        }

        T {
            anchors.centerIn: parent
            visible: root.apps.length === 0
            text: "No apps found"
            color: Theme.alpha(Theme.fg, 0.4)
        }
    }

    T {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: "Click to open · right-click to add to / remove from the dock (● = in dock)"
        color: Theme.alpha(Theme.fg, 0.4)
        font.pixelSize: 11
        font.weight: Font.Normal
    }
}
