import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components

// Applications folder: every app in a searchable grid.
// Click launches · right-click keeps it in / removes it from the dock · type to filter · Enter launches the first match.
// With `folder` set it picks that folder's apps instead: click adds / removes (✓ = in the folder).
ColumnLayout {
    id: root
    property bool open: false
    property string folder: ""
    readonly property var folderApps: Dock.folder(folder)?.apps ?? []
    signal done()
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
    function choose(a) { folder ? Dock.toggleInFolder(folder, a.id) : launch(a) }

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 40
        spacing: 10

        T { text: root.folder ? Icons.folderPlus : Icons.apps; color: Theme.primary; font.pixelSize: 18; Layout.leftMargin: 4 }
        T { text: root.folder ? `Add to “${Dock.folder(root.folder)?.name ?? ""}”` : "Applications"; font.pixelSize: 15 }
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
                    Keys.onReturnPressed: if (root.apps.length) root.choose(root.apps[0])
                    Keys.onEnterPressed: if (root.apps.length) root.choose(root.apps[0])
                    Keys.onDownPressed: { grid.currentIndex = 0; grid.forceActiveFocus() }
                    Keys.onTabPressed: { grid.currentIndex = 0; grid.forceActiveFocus() }
                    T {
                        visible: !search.text
                        text: "Search…"
                        color: Theme.alpha(Theme.fg, 0.4)
                        font.weight: Font.Normal
                    }
                }
            }
        }

        Rectangle {
            visible: !!root.folder
            Layout.preferredWidth: doneText.implicitWidth + 28
            Layout.preferredHeight: 34
            radius: Theme.radius
            color: dm.containsMouse ? Theme.mix(Theme.primary, "#ffffff", 0.15) : Theme.primary
            T { id: doneText; anchors.centerIn: parent; text: "Done"; color: Theme.primaryText }
            MouseArea { id: dm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.done() }
            KeyFocus { onActivated: root.done() }
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
        // arrows move (GridView built-in) · Enter opens / picks · Menu, Shift+F10 or Ctrl+P pins · ↑ on the top row or Shift+Tab back to search
        Keys.onPressed: e => {
            const a = root.apps[currentIndex]
            const pin = e.key === Qt.Key_Menu || (e.key === Qt.Key_F10 && (e.modifiers & Qt.ShiftModifier)) || (e.key === Qt.Key_P && (e.modifiers & Qt.ControlModifier))
            if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) && a) root.choose(a)
            else if (pin && a && !root.folder) Dock.togglePin(a.id)
            else if (e.key === Qt.Key_Tab) nextItemInFocusChain(true).forceActiveFocus()   // the Done button
            else if (e.key === Qt.Key_Backtab || (e.key === Qt.Key_Up && currentIndex < root.columns)) search.forceActiveFocus()
            else if (e.text && e.text.trim() && !e.modifiers) { search.forceActiveFocus(); search.text += e.text }
            else e.accepted = false
        }

        delegate: Item {
            id: tile
            required property var modelData
            readonly property bool pinned: root.folder ? root.folderApps.includes(modelData.id) : Dock.isPinned(modelData.id)
            width: root.cell
            height: root.cell

            Rectangle {
                anchors.fill: parent
                anchors.margins: 3
                radius: Theme.radius
                color: tm.containsMouse || (tile.GridView.isCurrentItem && grid.activeFocus) ? Theme.alpha(Theme.primary, 0.18) : "transparent"
                border.width: tile.GridView.isCurrentItem && grid.activeFocus ? 2 : 0
                border.color: Theme.fg
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
                visible: tile.pinned && !root.folder
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 12
                width: 8
                height: 8
                radius: 4
                color: Theme.primary
            }

            // in the folder
            Rectangle {
                visible: tile.pinned && !!root.folder
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 9
                width: 20
                height: 20
                radius: 10
                color: Theme.primary
                T { anchors.centerIn: parent; text: Icons.check; color: Theme.primaryText; font.pixelSize: 13 }
            }

            MouseArea {
                id: tm
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: e => root.folder ? root.choose(tile.modelData)
                    : e.button === Qt.RightButton ? Dock.togglePin(tile.modelData.id) : root.launch(tile.modelData)
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
        text: root.folder ? "Click to add to / remove from the folder (✓ = in folder) · Esc closes"
            : "Click / Enter to open · right-click / Ctrl+P to add to / remove from the dock (● = in dock)"
        color: Theme.alpha(Theme.fg, 0.4)
        font.pixelSize: 11
        font.weight: Font.Normal
    }
}
