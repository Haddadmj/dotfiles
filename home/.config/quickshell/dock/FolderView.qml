import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// What a dock folder opens: its apps in a grid under an editable name, or (page "add") the app picker.
//   click: open / focus · middle-click: new window · right-click: the app's dock menu
//   click the name to rename it · + picks which apps are in the folder
ColumnLayout {
    id: root
    property string folderId: ""
    property bool open: false
    property string page: "apps"           // apps · add
    property bool rename: false            // focus the name when opened (a new folder)
    signal appMenu(var app)
    signal pageRequested(string page)

    readonly property var item: Dock.items.find(i => i.id === folderId) ?? null
    readonly property var apps: item?.apps ?? []
    readonly property int columns: Math.max(3, Math.min(5, apps.length))
    readonly property int cell: 96
    spacing: 10

    onOpenChanged: {
        if (open && rename) Qt.callLater(() => { title.forceActiveFocus(); title.selectAll() })
        if (!open) title.focus = false
    }

    // ── the folder ───────────────────────────────────
    RowLayout {
        visible: root.page === "apps"
        Layout.fillWidth: true
        Layout.preferredHeight: 36
        spacing: 8

        T { text: Icons.folder; color: Theme.primary; font.pixelSize: 18; Layout.leftMargin: 4 }
        TextInput {
            id: title
            Layout.fillWidth: true
            text: root.item?.folder.name ?? ""
            color: Theme.fg
            selectionColor: Theme.primary
            selectedTextColor: Theme.primaryText
            font.family: Theme.font
            font.pixelSize: 15
            font.weight: Font.DemiBold
            clip: true
            onEditingFinished: Dock.renameFolder(root.folderId, text)
            Keys.onEscapePressed: { text = root.item?.folder.name ?? ""; focus = false }
            Rectangle {
                anchors.fill: parent
                anchors.margins: -5
                z: -1
                radius: 6
                color: "transparent"
                border.width: 1
                border.color: title.activeFocus ? Theme.alpha(Theme.primary, 0.6) : "transparent"
            }
        }
        Rectangle {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            radius: 15
            color: am.containsMouse ? Theme.alpha(Theme.primary, 0.25) : Theme.alpha(Theme.secondary, 0.6)
            T { anchors.centerIn: parent; text: Icons.plus; color: Theme.primary; font.pixelSize: 15 }
            MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.pageRequested("add") }
            KeyFocus { onActivated: root.pageRequested("add") }
        }
    }

    Grid {
        visible: root.page === "apps"
        columns: root.columns
        Layout.preferredWidth: root.columns * root.cell
        Layout.minimumHeight: root.cell

        Repeater {
            model: root.page === "apps" ? root.apps : []

            Item {
                id: tile
                required property var modelData
                width: root.cell
                height: root.cell + 6

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 3
                    radius: Theme.radius
                    color: tm.containsMouse ? Theme.alpha(Theme.primary, 0.18) : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width - 12
                    spacing: 5
                    AppIcon {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 50
                        Layout.preferredHeight: 50
                        icon: tile.modelData.entry?.icon || tile.modelData.id
                        sourceSize: Qt.size(100, 100)
                        scale: tm.pressed ? 0.9 : 1
                        Behavior on scale { NumberAnimation { duration: 120 } }
                    }
                    T {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: tile.modelData.entry?.name ?? tile.modelData.id
                        elide: Text.ElideRight
                        font.pixelSize: 11
                        font.weight: Font.Medium
                    }
                    // open-window dot
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 4
                        Layout.preferredHeight: 4
                        radius: 2
                        color: tile.modelData.windows.some(t => t.activated) ? Theme.primary : Theme.fgDim
                        opacity: tile.modelData.windows.length ? 1 : 0
                    }
                }

                KeyFocus {
                    anchors.margins: 3
                    radius: Theme.radius
                    onActivated: { Ui.popup = ""; Dock.activate(tile.modelData) }
                    Keys.onPressed: e => {
                        if (e.key === Qt.Key_Menu || (e.key === Qt.Key_F10 && (e.modifiers & Qt.ShiftModifier))) root.appMenu(tile.modelData)
                        else e.accepted = false
                    }
                }

                MouseArea {
                    id: tm
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: e => {
                        if (e.button === Qt.RightButton) return root.appMenu(tile.modelData)
                        Ui.popup = ""
                        if (e.button === Qt.MiddleButton) Dock.launch(tile.modelData.id)
                        else Dock.activate(tile.modelData)
                    }
                }
            }
        }
    }

    T {
        visible: root.page === "apps" && root.apps.length === 0
        Layout.preferredWidth: root.columns * root.cell
        horizontalAlignment: Text.AlignHCenter
        text: "Empty folder: press + to add apps,\nor drag a dock icon onto it"
        color: Theme.alpha(Theme.fg, 0.4)
        font.pixelSize: 12
        font.weight: Font.Normal
    }

    // ── picking its apps ─────────────────────────────
    AppsGrid {
        visible: root.page === "add"
        folder: root.page === "add" ? root.folderId : ""
        open: root.open && root.page === "add"
        onDone: root.pageRequested("apps")
    }
}
