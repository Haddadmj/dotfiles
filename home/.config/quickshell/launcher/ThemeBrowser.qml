import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.components

// Theme browser (SUPER+CTRL+I → qs ipc call themes toggle). Searches Pling for cursor and icon
// themes through theme-store.py, which does the downloading and installing; appearance.sh applies them.
// Names and text come from strangers on the internet, so they're always shown as plain text.
// Type to search · arrows move · Tab cursors/icons · Enter open · Esc close.
// Open theme: ↑↓ file · ←→ picture · Enter install/apply · Delete remove · Esc back.
PanelWindow {
    id: root
    readonly property bool open: Ui.themeBrowser
    readonly property string home: Quickshell.env("HOME")
    readonly property string store: home + "/.config/hypr/scripts/theme-store.py"
    readonly property string appearance: home + "/.config/hypr/scripts/appearance.sh"

    property string kind: "cursor"   // cursor or icons
    property var items: []           // { id, name, author, score, downloads, previews, files }
    property var installed: ({})     // theme name → { id, kind, file }
    property int total: 0
    property int pageSize: 24
    property int page: 0
    property string error: ""
    property bool rerun: false       // kind or search changed while a search was running
    property var activeTheme: ({ cursor: "", icons: "" })

    property var detail: null        // the theme that's open
    property int fileIndex: 0
    property int previewIndex: 0
    property string status: ""
    property bool statusBad: false
    property string actionKind: ""   // kind of the install still running, the tab may change meanwhile
    readonly property bool busy: action.running
    readonly property bool hasMore: (page + 1) * pageSize < total

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    WlrLayershell.namespace: "quickshell:themes"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: false

    onOpenChanged: {
        if (open) {
            hideTimer.stop()
            detail = null
            readActive.running = true
            if (!items.length) newSearch()
            visible = true
            search.forceActiveFocus()
        } else hideTimer.restart()
    }
    Timer { id: hideTimer; interval: Theme.anim; onTriggered: root.visible = false }
    Timer { id: typing; interval: 350; onTriggered: root.newSearch() }

    function newSearch() {
        page = 0
        items = []
        total = 0
        error = ""
        grid.currentIndex = 0
        runSearch()
    }
    function runSearch() {
        if (searcher.running) { rerun = true; return }
        searcher.command = [store, "search", kind, search.text.trim(), String(page)]
        searcher.running = true
    }
    function loadMore() {
        if (hasMore && !searcher.running) { page++; runSearch() }
    }
    function setKind(k) {
        if (kind !== k) { kind = k; newSearch() }
    }

    function parse(text) {
        try { return JSON.parse(text) }
        catch (e) { return { error: "Unexpected answer from theme-store.py" } }
    }

    Process {
        id: searcher
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.rerun) return
                const r = root.parse(text)
                if (r.error) { root.error = r.error; return }
                root.total = r.total
                root.pageSize = r.pageSize
                root.installed = r.installed
                root.items = root.items.concat(r.items)
                // a page can shrink to nothing once uninstallable items are filtered out
                if (!r.items.length) root.loadMoreLater()
            }
        }
        onRunningChanged: if (!running && root.rerun) {
            root.rerun = false
            Qt.callLater(root.newSearch)
        }
    }
    function loadMoreLater() { Qt.callLater(loadMore) }

    Process {
        id: readActive
        command: ["bash", "-c", `
            echo "$(cat "$HOME/.config/hypr/cursor-theme" 2>/dev/null)"
            gsettings get org.gnome.desktop.interface icon-theme | tr -d "'"`]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n")
                root.activeTheme = { cursor: lines[0] ?? "", icons: lines[1] ?? "" }
            }
        }
    }

    // one install or remove at a time
    Process {
        id: action
        stdout: StdioCollector {
            onStreamFinished: {
                const r = root.parse(text)
                root.statusBad = !!r.error
                if (r.error) { root.status = r.error; return }
                root.installed = r.installed
                if (r.removed) { root.status = "Removed " + r.removed; return }
                const names = r.themes.length ? r.themes : r.existing
                root.applyTheme(root.actionKind, names[0])
                const others = names.slice(1)
                root.status = "Applied " + names[0] + (others.length ? ` · also installed ${others.join(", ")} (SUPER+${root.actionKind === "cursor" ? "U" : "I"} to switch)` : "")
            }
        }
    }

    function namesFor(item, file) {
        if (!item) return []
        return Object.keys(installed).filter(n => installed[n].id === item.id && installed[n].file === file.name)
    }
    function applyTheme(k, name) {
        Quickshell.execDetached([appearance, "set", k, name])
        const a = Object.assign({}, activeTheme)
        a[k] = name
        activeTheme = a
    }
    function installOrApply() {
        const file = detail?.files[fileIndex]
        if (!file || busy) return
        const names = namesFor(detail, file)
        statusBad = false
        if (names.length) {
            applyTheme(kind, names[0])
            status = "Applied " + names[0]
            return
        }
        status = "Downloading " + file.name + "…"
        actionKind = kind
        action.command = [store, "install", kind, detail.id, String(file.number)]
        action.running = true
    }
    function removeSelected() {
        const file = detail?.files[fileIndex]
        if (!file || busy) return
        const names = namesFor(detail, file)
        if (!names.length) return
        statusBad = false
        status = "Removing " + names[0] + "…"
        action.command = [store, "remove", names[0]]
        action.running = true
    }
    function openDetail(item) {
        if (!item) return
        detail = item
        fileIndex = 0
        previewIndex = 0
        status = ""
    }
    function shortCount(n) {
        return n >= 1000000 ? (n / 1000000).toFixed(1) + "M" : n >= 1000 ? Math.round(n / 1000) + "k" : String(n)
    }

    // click outside the box closes
    MouseArea {
        anchors.fill: parent
        onClicked: Ui.themeBrowser = false
    }

    Rectangle {
        id: box
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 1100)
        height: Math.min(parent.height - 120, 720)
        radius: Theme.radius + 4
        color: Theme.popup
        border.width: 1
        border.color: Theme.alpha(Theme.primary, 0.35)
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.97
        Behavior on opacity { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }

        MouseArea { anchors.fill: parent }   // swallow clicks so they don't close

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // search
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 38
                    radius: Theme.radius
                    color: Theme.alpha(Theme.secondary, 0.6)
                    border.width: 1
                    border.color: search.activeFocus ? Theme.alpha(Theme.primary, 0.6) : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 10
                        T { text: Icons.search; color: Theme.primary; font.pixelSize: 16 }
                        TextInput {
                            id: search
                            Layout.fillWidth: true
                            color: Theme.fg
                            selectionColor: Theme.primary
                            selectedTextColor: Theme.primaryText
                            font.family: Theme.font
                            font.pixelSize: 14
                            clip: true
                            readOnly: root.detail !== null
                            onTextChanged: typing.restart()

                            T {
                                visible: !search.text
                                text: "Search Pling for themes…"
                                color: Theme.alpha(Theme.fg, 0.4)
                                font.pixelSize: 14
                                font.weight: Font.Normal
                            }

                            Keys.onPressed: e => {
                                if (root.detail) {
                                    if (e.key === Qt.Key_Escape) root.detail = null
                                    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.installOrApply()
                                    else if (e.key === Qt.Key_Delete) root.removeSelected()
                                    else if (e.key === Qt.Key_Up) root.fileIndex = Math.max(0, root.fileIndex - 1)
                                    else if (e.key === Qt.Key_Down) root.fileIndex = Math.min(root.detail.files.length - 1, root.fileIndex + 1)
                                    else if (e.key === Qt.Key_Left) root.previewIndex = Math.max(0, root.previewIndex - 1)
                                    else if (e.key === Qt.Key_Right) root.previewIndex = Math.min(root.detail.previews.length - 1, root.previewIndex + 1)
                                    else return
                                } else {
                                    if (e.key === Qt.Key_Escape) Ui.themeBrowser = false
                                    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.openDetail(root.items[grid.currentIndex])
                                    else if (e.key === Qt.Key_Left) grid.moveCurrentIndexLeft()
                                    else if (e.key === Qt.Key_Right) grid.moveCurrentIndexRight()
                                    else if (e.key === Qt.Key_Up) grid.moveCurrentIndexUp()
                                    else if (e.key === Qt.Key_Down) grid.moveCurrentIndexDown()
                                    else if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab) root.setKind(root.kind === "cursor" ? "icons" : "cursor")
                                    else return
                                }
                                e.accepted = true
                            }
                        }
                        T { text: root.total; color: Theme.fgDim; font.pixelSize: 11 }
                    }
                }

                // cursors / icons
                Repeater {
                    model: [{ id: "cursor", label: "Cursors" }, { id: "icons", label: "Icons" }]
                    delegate: Rectangle {
                        id: chip
                        required property var modelData
                        readonly property bool active: root.kind === modelData.id
                        implicitWidth: chipText.implicitWidth + 24
                        implicitHeight: 38
                        radius: Theme.radius
                        color: active ? Theme.primary : cm.containsMouse ? Theme.alpha(Theme.secondary, 0.9) : Theme.alpha(Theme.secondary, 0.4)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        T {
                            id: chipText
                            anchors.centerIn: parent
                            text: chip.modelData.label
                            color: chip.active ? Theme.primaryText : Theme.fg
                        }
                        MouseArea {
                            id: cm
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.detail = null; root.setKind(chip.modelData.id); search.forceActiveFocus() }
                        }
                    }
                }
            }

            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: Math.floor(width / 4)
                cellHeight: Math.floor(cellWidth * 9 / 16) + 44
                model: ScriptModel { values: root.items }
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 120
                onCurrentIndexChanged: if (currentIndex >= root.items.length - 8) root.loadMore()
                onAtYEndChanged: if (atYEnd && root.items.length) root.loadMore()
                WheelScroll { view: grid }

                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property bool selected: GridView.isCurrentItem
                    readonly property bool hasInstalled: Object.keys(root.installed).some(n => root.installed[n].id === modelData.id)
                    width: grid.cellWidth
                    height: grid.cellHeight

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 2

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 10
                            color: cell.selected ? Theme.primary : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }

                            ClippingRectangle {
                                anchors.fill: parent
                                anchors.margins: 3
                                radius: 8
                                color: Theme.alpha(Theme.secondary, 0.8)
                                Image {
                                    id: thumb
                                    anchors.fill: parent
                                    source: cell.modelData.previews[0] ?? ""
                                    sourceSize.width: 480
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    scale: cell.selected ? 1.04 : 1
                                    Behavior on scale { NumberAnimation { duration: 150 } }
                                }
                                T {
                                    anchors.centerIn: parent
                                    visible: thumb.status !== Image.Ready
                                    text: Icons.image
                                    font.pixelSize: 22
                                    color: Theme.alpha(Theme.fg, 0.3)
                                }
                            }

                            // badge on themes installed from here
                            Rectangle {
                                visible: cell.hasInstalled
                                anchors { top: parent.top; right: parent.right; margins: 9 }
                                width: 22; height: 22; radius: 11
                                color: Theme.primary
                                T { anchors.centerIn: parent; text: Icons.check; color: Theme.primaryText; font.pixelSize: 13 }
                            }
                        }
                        T {
                            Layout.fillWidth: true
                            text: cell.modelData.name
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: 12
                            color: cell.selected ? Theme.fg : Theme.fgDim
                        }
                        T {
                            Layout.fillWidth: true
                            text: `${cell.modelData.score}% · ${root.shortCount(cell.modelData.downloads)} downloads`
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: 10
                            font.weight: Font.Normal
                            color: Theme.alpha(Theme.fg, 0.45)
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: if (!root.detail) grid.currentIndex = cell.index
                        onClicked: root.openDetail(cell.modelData)
                    }
                }

                T {
                    anchors.centerIn: parent
                    width: parent.width - 60
                    visible: root.items.length === 0
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                    horizontalAlignment: Text.AlignHCenter
                    text: root.error ? "Couldn't reach Pling: " + root.error : searcher.running ? "Searching…" : "No themes found"
                    color: root.error ? Theme.error : Theme.alpha(Theme.fg, 0.4)
                }
            }

            T {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: "Enter / click open · Tab cursors/icons · Esc close · themes are uploaded by users on pling.com"
                color: Theme.alpha(Theme.fg, 0.4)
                font.pixelSize: 11
                font.weight: Font.Normal
            }
        }

        // one theme: pictures, its files, install / apply / remove
        Rectangle {
            id: themePage
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius
            color: Theme.bg
            visible: opacity > 0
            opacity: root.detail ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }
            readonly property var previews: root.detail?.previews ?? []

            MouseArea { anchors.fill: parent }   // the grid underneath must not react

            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 14

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8

                    ClippingRectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Theme.radius
                        color: Theme.alpha(Theme.secondary, 0.5)
                        Image {
                            id: big
                            anchors.fill: parent
                            source: root.detail ? (themePage.previews[root.previewIndex] ?? "") : ""
                            sourceSize.width: 1200
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }
                        T {
                            anchors.centerIn: parent
                            visible: big.status !== Image.Ready
                            text: big.status === Image.Error || !themePage.previews.length ? "No picture" : "Loading…"
                            color: Theme.alpha(Theme.fg, 0.4)
                        }
                    }

                    // picture dots
                    Row {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 6
                        visible: themePage.previews.length > 1
                        Repeater {
                            model: themePage.previews.length
                            delegate: Rectangle {
                                required property int index
                                width: 8; height: 8; radius: 4
                                color: index === root.previewIndex ? Theme.primary : Theme.alpha(Theme.fg, 0.25)
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -3
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.previewIndex = parent.index
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.preferredWidth: 340
                    Layout.maximumWidth: 340
                    Layout.fillHeight: true
                    spacing: 8

                    T {
                        Layout.fillWidth: true
                        text: root.detail?.name ?? ""
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        font.pixelSize: 18
                    }
                    T {
                        Layout.fillWidth: true
                        text: root.detail ? `by ${root.detail.author} · ${root.detail.score}% · ${root.shortCount(root.detail.downloads)} downloads` : ""
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        font.pixelSize: 11
                        font.weight: Font.Normal
                        color: Theme.fgDim
                    }

                    ListView {
                        id: files
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.topMargin: 6
                        clip: true
                        spacing: 4
                        model: root.detail?.files ?? []
                        currentIndex: root.fileIndex
                        boundsBehavior: Flickable.StopAtBounds
                        WheelScroll { view: files }

                        delegate: Rectangle {
                            id: row
                            required property var modelData
                            required property int index
                            readonly property var names: root.namesFor(root.detail, modelData)
                            readonly property bool inUse: names.includes(root.activeTheme[root.kind])
                            readonly property bool selected: root.fileIndex === index
                            width: files.width
                            implicitHeight: 52
                            radius: Theme.radius
                            color: selected ? Theme.alpha(Theme.primary, 0.25) : rowMouse.containsMouse ? Theme.alpha(Theme.secondary, 0.7) : Theme.alpha(Theme.secondary, 0.35)
                            border.width: selected ? 1 : 0
                            border.color: Theme.alpha(Theme.primary, 0.7)

                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { root.fileIndex = row.index; root.installOrApply() }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 8
                                spacing: 8
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    T {
                                        Layout.fillWidth: true
                                        text: row.modelData.name
                                        textFormat: Text.PlainText
                                        elide: Text.ElideMiddle
                                        font.pixelSize: 12
                                    }
                                    T {
                                        Layout.fillWidth: true
                                        text: {
                                            const mb = (row.modelData.size / 1024).toFixed(1) + " MB"
                                            if (row.inUse) return mb + " · in use"
                                            return row.names.length ? mb + " · installed, Enter to apply" : mb + " · Enter to install"
                                        }
                                        font.pixelSize: 10
                                        font.weight: Font.Normal
                                        color: row.inUse ? Theme.primary : Theme.fgDim
                                    }
                                }
                                Rectangle {
                                    visible: row.names.length > 0
                                    implicitWidth: 32
                                    implicitHeight: 32
                                    radius: Theme.radius
                                    color: rmMouse.containsMouse ? Theme.alpha(Theme.error, 0.9) : "transparent"
                                    T {
                                        anchors.centerIn: parent
                                        text: Icons.trash
                                        font.pixelSize: 14
                                        color: rmMouse.containsMouse ? Theme.errorText : Theme.fgDim
                                    }
                                    MouseArea {
                                        id: rmMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { root.fileIndex = row.index; root.removeSelected() }
                                    }
                                }
                            }
                        }
                    }

                    T {
                        Layout.fillWidth: true
                        visible: root.status !== ""
                        text: root.status
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        font.pixelSize: 12
                        color: root.statusBad ? Theme.error : Theme.primary
                    }
                    T {
                        Layout.fillWidth: true
                        text: "Enter install / apply · ↑↓ file · ←→ picture · Del remove · Esc back"
                        wrapMode: Text.Wrap
                        font.pixelSize: 11
                        font.weight: Font.Normal
                        color: Theme.alpha(Theme.fg, 0.4)
                    }
                }
            }
        }
    }
}
