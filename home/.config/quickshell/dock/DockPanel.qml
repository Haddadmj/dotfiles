import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components

// macOS-style dock along the bottom: pinned apps, then other open apps │ Applications folder, Trash.
//   click: open / focus (again cycles windows) · middle-click: new window · right-click: menu
//   drag an icon sideways to reorder, drag it up out of the dock to remove it, drop files on the Trash
//   right-click the dock background for hiding (dodge windows · always · never) and magnification.
//   SUPER+D toggles it. It never reserves space: it floats over windows and hides when one covers it.
// State lives in the Dock singleton (pinned apps are shared with the launcher).
PanelWindow {
    id: root
    required property var modelData
    screen: modelData

    readonly property int base: 48            // icon size
    readonly property int maxSize: Dock.magnify ? 74 : base
    readonly property int pad: 8
    readonly property int sp: 6
    readonly property int sepW: 13
    readonly property int margin: 8
    readonly property int dockH: base + pad * 2 + 4

    readonly property string menuName: "dock-menu:" + screen.name
    readonly property string appsName: "dock-apps:" + screen.name

    // ── visibility ───────────────────────────────────
    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property var workspace: monitor?.activeWorkspace ?? null
    readonly property bool popupOpen: Ui.popup === menuName || Ui.popup === appsName
    property bool hoverHold: false

    // a window on this screen's workspace overlaps where the (un-magnified) dock sits
    readonly property bool covered: {
        const ws = workspace
        if (!ws) return false
        if (ws.hasFullscreen) return true
        const w = baseWidth + pad * 2
        const left = screen.x + (screen.width - w) / 2
        const top = screen.y + screen.height - margin - dockH
        return ws.toplevels.values.some(t => {
            const o = t.lastIpcObject
            if (!o?.at || !o?.size || o.hidden) return false
            return o.at[0] < left + w && o.at[0] + o.size[0] > left && o.at[1] + o.size[1] > top
        })
    }
    readonly property bool autoShown: Dock.hideMode === "never" || (Dock.hideMode === "dodge" && !covered)
    readonly property bool shown: popupOpen || dragId !== "" || hoverHold || trashDrop.containsDrag
        || Dock.override === "show" || (Dock.override === "" && autoShown)

    // floating windows can be dragged without any Hyprland event, so poll while there are some
    Timer {
        running: Dock.hideMode === "dodge" && (root.workspace?.toplevels.values.some(t => t.lastIpcObject?.floating) ?? false)
        interval: 1000
        repeat: true
        onTriggered: Dock.refreshWindows()
    }

    // SUPER+D: flip what's on screen now; returns to automatic when that already matches
    Connections {
        target: Dock
        function onToggleRequested() {
            if (Hyprland.focusedMonitor !== root.monitor) return
            if (root.shown) Dock.override = root.autoShown ? "hide" : ""
            else Dock.override = root.autoShown ? "" : "show"
            leaveTimer.stop()
            root.hoverHold = false
        }
    }

    Connections {
        target: hover
        function onHoveredChanged() {
            if (hover.hovered) { leaveTimer.stop(); root.hoverHold = true }
            else leaveTimer.restart()
        }
    }
    Timer { id: leaveTimer; interval: 350; onTriggered: root.hoverHold = false }

    WlrLayershell.namespace: "quickshell:dock"
    WlrLayershell.layer: WlrLayer.Top
    anchors { bottom: true; left: true; right: true }
    implicitHeight: dockH + margin + (maxSize - base) + 44   // room for magnified icons and name bubbles
    exclusionMode: ExclusionMode.Ignore              // float over windows instead of shrinking them
    color: "transparent"
    // only the dock itself (or a thin strip at the screen edge while hidden) takes input
    mask: Region { item: hitArea }

    Item {
        id: hitArea
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.shown ? bg.width : Math.max(bg.width, 300)
        height: root.shown ? root.dockH + root.margin + (hover.hovered && Dock.magnify ? root.maxSize - root.base : 0) : 3
    }

    // ── magnification ────────────────────────────────
    // Measured against the un-magnified layout so growing icons don't move what's under the pointer.
    readonly property int count: Dock.items.length
    readonly property real baseWidth: (count + 2) * base + (count + 2) * sp + sepW
    function baseCenter(k) { return k * (base + sp) + base / 2 + (k >= count ? sepW + sp : 0) }
    readonly property real pointer: hover.hovered && dragId === "" ? hover.point.position.x - (width - baseWidth) / 2 : -1e6
    function sizeAt(k) {
        if (!Dock.magnify) return base
        const d = Math.abs(baseCenter(k) - pointer)
        const r = base * 2.6
        return d >= r ? base : base + (maxSize - base) * (1 + Math.cos(Math.PI * d / r)) / 2
    }

    // ── dragging ─────────────────────────────────────
    property string dragId: ""
    property bool dragOut: false        // pointer is well above the dock: dropping removes the icon
    function slotAt(x) { return Math.round((x - (width - baseWidth) / 2 - base / 2) / (base + sp)) }
    function dragTo(item, x, y) {
        dragId = item.id
        dragOut = item.pinned && y < height - dockH - margin - 70
    }
    function dropAt(item, x, y) {
        if (dragOut) Dock.unpin(item.id)
        else if (item.entry) {
            const k = slotAt(x)
            if (item.pinned) Dock.movePinned(item.id, k)
            else if (k <= Dock.pinned.length) { Dock.pin(item.id); Dock.movePinned(item.id, k) }
        }
        dragId = ""
        dragOut = false
    }

    // ── trash ────────────────────────────────────────
    FolderListModel {
        id: trash
        folder: "file://" + Quickshell.env("HOME") + "/.local/share/Trash/files"
        showHidden: true
        showDirs: true
        showDotAndDotDot: false
    }
    function openTrash() { Quickshell.execDetached(["sh", "-c", "dolphin trash:/ || gio open trash:///"]) }

    // ── menu ─────────────────────────────────────────
    property string menuKind: ""        // app · trash · apps · dock
    property var menuApp: null
    function openMenu(kind, target, app) {
        menuKind = kind
        menuApp = app ?? null
        menu.target = target
        Ui.popup = menuName
    }

    function toggleApps() { Ui.toggle(appsName) }

    // ── the dock ─────────────────────────────────────
    Item {
        id: slide
        anchors.fill: parent
        transform: Translate {
            y: root.shown ? 0 : root.dockH + root.margin + 6
            Behavior on y { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
        }

        HoverHandler { id: hover }

        // a file dragged to the screen edge reveals the dock so it can be dropped on the Trash
        DropArea {
            anchors.fill: parent
            keys: ["text/uri-list"]
            onEntered: { leaveTimer.stop(); root.hoverHold = true }
            onExited: leaveTimer.restart()
        }

        Rectangle {
            id: bg
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.margin
            anchors.horizontalCenter: parent.horizontalCenter
            width: row.width + root.pad * 2
            height: root.dockH
            radius: 18
            color: Theme.island
            border.width: 1
            border.color: Theme.islandBorder
            Behavior on color { ColorAnimation { duration: Theme.anim } }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onClicked: root.openMenu("dock", bg)
            }
        }

        Row {
            id: row
            anchors.bottom: bg.bottom
            anchors.bottomMargin: root.pad + 4
            anchors.horizontalCenter: bg.horizontalCenter
            spacing: root.sp

            Repeater {
                // keyed on id so delegates survive windows opening/closing
                model: ScriptModel { values: Dock.items.map(i => i.id) }

                DockIcon {
                    id: app
                    required property string modelData
                    required property int index
                    readonly property var item: Dock.items.find(i => i.id === modelData) ?? { id: modelData, windows: [] }
                    size: root.sizeAt(index)
                    maxSize: root.maxSize
                    iconName: item.entry?.icon || modelData
                    label: item.entry?.name ?? modelData
                    windows: item.windows.length
                    active: item.windows.some(t => t.activated)
                    bouncing: Dock.launching === modelData
                    draggable: true
                    dimmed: dragging && root.dragOut
                    onClicked: e => {
                        Ui.popup = ""
                        if (e.button === Qt.RightButton) root.openMenu("app", app.iconItem, item)
                        else if (e.button === Qt.MiddleButton) Dock.launch(modelData)
                        else Dock.activate(item)
                    }
                    onDragMoved: (x, y) => root.dragTo(item, x, y)
                    onDropped: (x, y) => root.dropAt(item, x, y)
                }
            }

            Item {
                width: root.sepW
                height: root.maxSize
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    width: 1
                    height: root.base
                    color: Theme.islandBorder
                }
            }

            DockIcon {
                id: appsIcon
                size: root.sizeAt(root.count)
                maxSize: root.maxSize
                glyph: Icons.apps
                label: "Applications"
                active: Ui.popup === root.appsName
                onClicked: e => {
                    if (e.button === Qt.RightButton) root.openMenu("apps", appsIcon.iconItem)
                    else root.toggleApps()
                }
            }

            DockIcon {
                id: trashIcon
                size: root.sizeAt(root.count + 1)
                maxSize: root.maxSize
                iconName: trash.count > 0 ? "user-trash-full" : "user-trash"
                label: trash.count > 0 ? `Trash (${trash.count})` : "Trash"
                highlight: trashDrop.containsDrag
                onClicked: e => {
                    Ui.popup = ""
                    if (e.button === Qt.RightButton) root.openMenu("trash", trashIcon.iconItem)
                    else root.openTrash()
                }

                DropArea {
                    id: trashDrop
                    anchors.fill: parent
                    keys: ["text/uri-list"]
                    onDropped: drop => {
                        if (!drop.hasUrls) return
                        Quickshell.execDetached(["gio", "trash", ...drop.urls.map(u => u.toString())])
                        drop.acceptProposedAction()
                    }
                }
            }
        }

        // "Remove" hint while an icon is dragged out of the dock
        T {
            anchors.horizontalCenter: bg.horizontalCenter
            anchors.bottom: bg.top
            anchors.bottomMargin: root.maxSize - root.base + 40
            visible: root.dragOut
            text: Icons.trash + "  Remove from Dock"
            color: Theme.error
        }
    }

    // ── popups ───────────────────────────────────────
    BarPopup {
        id: menu
        name: root.menuName
        target: bg
        above: true

        // app: its windows, then actions
        Repeater {
            model: root.menuKind === "app" ? (root.menuApp?.windows ?? []) : []
            MenuItem {
                required property var modelData
                icon: Icons.window
                text: modelData.title || root.menuApp?.entry?.name || ""
                active: modelData.activated
                Layout.maximumWidth: 320
                onClicked: { Ui.popup = ""; Dock.focusWindow(modelData) }
            }
        }
        Rectangle {
            visible: root.menuKind === "app" && (root.menuApp?.windows.length ?? 0) > 0
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.islandBorder
        }
        MenuItem {
            visible: root.menuKind === "app" && !!root.menuApp?.entry
            icon: Icons.plus
            text: (root.menuApp?.windows.length ?? 0) > 0 ? "New window" : "Open"
            onClicked: { Ui.popup = ""; Dock.launch(root.menuApp.id) }
        }
        MenuItem {
            visible: root.menuKind === "app" && !!root.menuApp?.entry
            readonly property bool pinned: root.menuApp ? Dock.pinned.includes(root.menuApp.id) : false
            icon: pinned ? Icons.close : Icons.check
            text: pinned ? "Remove from Dock" : "Keep in Dock"
            onClicked: { Ui.popup = ""; Dock.togglePin(root.menuApp.id) }
        }
        MenuItem {
            visible: root.menuKind === "app" && (root.menuApp?.windows.length ?? 0) > 0
            icon: Icons.power
            text: (root.menuApp?.windows.length ?? 0) > 1 ? `Quit (${root.menuApp.windows.length} windows)` : "Quit"
            hoverColor: Theme.error
            hoverText: Theme.errorText
            onClicked: { Ui.popup = ""; root.menuApp.windows.forEach(t => Dock.closeWindow(t)) }
        }

        // trash
        MenuItem {
            visible: root.menuKind === "trash"
            icon: Icons.trash
            text: "Open Trash"
            onClicked: { Ui.popup = ""; root.openTrash() }
        }
        MenuItem {
            visible: root.menuKind === "trash" && trash.count > 0
            icon: Icons.close
            text: `Empty Trash (${trash.count})`
            hoverColor: Theme.error
            hoverText: Theme.errorText
            onClicked: { Ui.popup = ""; Quickshell.execDetached(["gio", "trash", "--empty"]) }
        }

        // applications folder
        MenuItem {
            visible: root.menuKind === "apps"
            icon: Icons.apps
            text: "Show Applications"
            onClicked: { Ui.popup = ""; root.toggleApps() }
        }
        MenuItem {
            visible: root.menuKind === "apps"
            icon: Icons.search
            text: "Open Launcher"
            onClicked: { Ui.popup = ""; Ui.toggleLauncher("apps") }
        }

        // dock settings (background, or under the apps folder)
        T {
            visible: root.menuKind === "dock" || root.menuKind === "apps"
            text: "Hide dock"
            color: Theme.fgDim
            font.pixelSize: 11
            Layout.leftMargin: 14
            Layout.topMargin: 4
        }
        Repeater {
            model: root.menuKind === "dock" || root.menuKind === "apps" ? [
                { mode: "dodge", text: "When a window covers it" },
                { mode: "always", text: "Always  (show at screen edge)" },
                { mode: "never", text: "Never" },
            ] : []
            MenuItem {
                required property var modelData
                icon: Dock.hideMode === modelData.mode ? Icons.check : " "
                text: modelData.text
                active: Dock.hideMode === modelData.mode
                onClicked: Dock.setHideMode(modelData.mode)
            }
        }
        MenuItem {
            visible: root.menuKind === "dock" || root.menuKind === "apps"
            icon: Dock.magnify ? Icons.check : " "
            text: "Magnification"
            active: Dock.magnify
            onClicked: Dock.setMagnify(!Dock.magnify)
        }
    }

    BarPopup {
        name: root.appsName
        target: appsIcon.iconItem
        above: true
        align: 0.5
        padding: 14

        AppsGrid { open: Ui.popup === root.appsName }
    }
}
