import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.components

// Workspace overview (SUPER+Tab): every workspace of the focused monitor with live window previews.
// Click a window to focus it · drag it onto another workspace to move it · click empty space to switch
// workspace · 1-9 jump · Esc / SUPER+Tab / click outside close.
PanelWindow {
    id: root
    readonly property bool open: Ui.overview
    readonly property var monitor: Hyprland.focusedMonitor
    readonly property real mw: monitor?.width ?? 1920
    readonly property real mh: monitor?.height ?? 1080
    readonly property real cellW: Math.min(560, (width - 160) / Math.min(3, Math.max(1, workspaces.length)))
    readonly property real scale: cellW / (mw / (monitor?.scale ?? 1))

    // existing workspaces on this monitor plus an empty "next" one to drop windows on
    readonly property var workspaces: {
        const ws = Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor === monitor).map(w => w.id).sort((a, b) => a - b)
        const next = Math.max(0, ...Hyprland.workspaces.values.map(w => w.id)) + 1
        return [...ws, next]
    }

    screen: Quickshell.screens.find(s => s.name === monitor?.name) ?? Quickshell.screens[0]
    WlrLayershell.namespace: "quickshell:overview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: false

    onOpenChanged: {
        if (open) {
            hideTimer.stop()
            Hyprland.refreshToplevels()
            Hyprland.refreshWorkspaces()
            visible = true
            content.forceActiveFocus()
        } else hideTimer.restart()
    }
    Timer { id: hideTimer; interval: Theme.anim; onTriggered: root.visible = false }

    function addr(t) { const a = t.address; return a.startsWith("0x") ? a : "0x" + a }
    function focusWindow(t) {
        Hyprland.dispatch(`hl.dsp.focus({ window = "address:${addr(t)}" })`)
        Ui.overview = false
    }
    function gotoWorkspace(id) {
        Hyprland.dispatch(`hl.dsp.focus({ workspace = "${id}" })`)
        Ui.overview = false
    }
    function moveWindow(t, id) {
        Hyprland.dispatch(`hl.dsp.window.move({ workspace = "${id}", window = "address:${addr(t)}", follow = false })`)
        refresh.restart()
    }
    Timer { id: refresh; interval: 120; onTriggered: Hyprland.refreshToplevels() }

    // drag state: a ghost preview follows the pointer at root level
    property var dragging: null
    function wsAt(item, x, y) {
        for (let i = 0; i < wsRepeater.count; i++) {
            const cell = wsRepeater.itemAt(i)
            const p = item.mapToItem(cell, x, y)
            if (p.x >= 0 && p.y >= 0 && p.x <= cell.width && p.y <= cell.height) return cell.wsId
        }
        return null
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.bg, 0.55)
        opacity: root.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.anim } }
        MouseArea { anchors.fill: parent; onClicked: Ui.overview = false }
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }

        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape || e.key === Qt.Key_Tab) Ui.overview = false
            else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_9) root.gotoWorkspace(e.key - Qt.Key_0)
            else return
            e.accepted = true
        }

        GridLayout {
            anchors.centerIn: parent
            columns: Math.min(3, root.workspaces.length)
            rowSpacing: 26
            columnSpacing: 26

            Repeater {
                id: wsRepeater
                model: root.workspaces

                delegate: ColumnLayout {
                    id: cell
                    required property int modelData
                    readonly property int wsId: modelData
                    readonly property var ws: Hyprland.workspaces.values.find(w => w.id === wsId) ?? null
                    readonly property bool current: root.monitor?.activeWorkspace?.id === wsId
                    readonly property bool target: root.dragging !== null && dropHint
                    property bool dropHint: false
                    spacing: 6

                    T {
                        text: cell.ws ? `${Icons.workspaces[cell.wsId] ?? Icons.wsDefault}  ${cell.wsId}` : `+  new (${cell.wsId})`
                        color: cell.current ? Theme.primary : Theme.fg
                    }

                    Rectangle {
                        implicitWidth: root.cellW
                        implicitHeight: root.cellW * root.mh / root.mw
                        radius: Theme.radius + 2
                        color: Theme.alpha(Theme.bg, 0.85)
                        border.width: cell.target ? 3 : cell.current ? 2 : 1
                        border.color: cell.target ? Theme.tertiary : cell.current ? Theme.primary : Theme.islandBorder
                        clip: true

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.gotoWorkspace(cell.wsId)
                        }

                        Repeater {
                            model: cell.ws?.toplevels.values ?? []
                            delegate: Item {
                                id: win
                                required property var modelData
                                readonly property var ipc: modelData.lastIpcObject
                                readonly property var at: ipc?.at ?? [0, 0]
                                readonly property var size: ipc?.size ?? [0, 0]
                                visible: size[0] > 0
                                x: (at[0] - (root.monitor?.x ?? 0)) * root.scale
                                y: (at[1] - (root.monitor?.y ?? 0)) * root.scale
                                z: ipc?.floating ? 1 : 0
                                width: size[0] * root.scale
                                height: size[1] * root.scale
                                opacity: root.dragging === modelData ? 0.3 : 1

                                ClippingRectangle {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    radius: 6
                                    color: Theme.alpha(Theme.secondary, 0.9)
                                    border.width: wm.containsMouse ? 2 : 0
                                    border.color: Theme.primary

                                    ScreencopyView {
                                        anchors.fill: parent
                                        captureSource: root.open ? win.modelData.wayland : null
                                        live: true
                                        constraintSize: Qt.size(width, height)
                                    }
                                    IconImage {
                                        anchors.centerIn: parent
                                        implicitSize: Math.min(40, parent.height * 0.5)
                                        source: Quickshell.iconPath(DesktopEntries.heuristicLookup(win.ipc?.class ?? "")?.icon ?? "", true)
                                        opacity: 0.9
                                    }
                                }

                                MouseArea {
                                    id: wm
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                    property point start
                                    onPressed: e => start = Qt.point(e.x, e.y)
                                    onPositionChanged: e => {
                                        if (!pressed) return
                                        if (!root.dragging && Math.hypot(e.x - start.x, e.y - start.y) > 6) {
                                            root.dragging = win.modelData
                                            ghost.width = win.width; ghost.height = win.height
                                            ghost.toplevel = win.modelData
                                        }
                                        if (root.dragging) {
                                            const p = mapToItem(content, e.x, e.y)
                                            ghost.x = p.x - ghost.width / 2; ghost.y = p.y - ghost.height / 2
                                            const target = root.wsAt(wm, e.x, e.y)
                                            for (let i = 0; i < wsRepeater.count; i++) wsRepeater.itemAt(i).dropHint = wsRepeater.itemAt(i).wsId === target
                                        }
                                    }
                                    onReleased: e => {
                                        if (root.dragging) {
                                            const target = root.wsAt(wm, e.x, e.y)
                                            if (target !== null && target !== cell.wsId) root.moveWindow(win.modelData, target)
                                            root.dragging = null
                                            for (let i = 0; i < wsRepeater.count; i++) wsRepeater.itemAt(i).dropHint = false
                                        }
                                    }
                                    onClicked: e => {
                                        if (e.button === Qt.MiddleButton) {
                                            Hyprland.dispatch(`hl.dsp.window.close({ window = "address:${root.addr(win.modelData)}" })`)
                                            refresh.restart()
                                        } else if (!root.dragging) root.focusWindow(win.modelData)
                                    }
                                }

                                Tip { target: win; show: wm.containsMouse && !root.dragging; text: win.modelData.title }
                            }
                        }
                    }
                }
            }
        }

        // preview that follows the pointer while dragging
        ClippingRectangle {
            id: ghost
            property var toplevel: null
            visible: root.dragging !== null
            radius: 6
            color: Theme.alpha(Theme.secondary, 0.9)
            border.width: 2
            border.color: Theme.tertiary
            ScreencopyView {
                anchors.fill: parent
                captureSource: root.dragging ? ghost.toplevel?.wayland ?? null : null
                live: true
            }
        }

        T {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 40
            anchors.horizontalCenter: parent.horizontalCenter
            text: "click focus · drag to another workspace · middle-click close · 1-9 jump · Esc close"
            color: Theme.alpha(Theme.fg, 0.6)
            font.weight: Font.Normal
        }
    }
}
