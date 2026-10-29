import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.components

// Wallpaper picker (SUPER+W → theme.sh pick → qs ipc call wallpapers toggle).
// Grid of thumbnails from ~/Pictures/Wallpapers; picking one runs `theme.sh set <file>`,
// which also regenerates the colors. Thumbnails are shared with theme.sh's wofi fallback.
// Type to search · arrows move · Tab cycles folder · Space / right-click full preview · Ctrl+D light/dark
// · Ctrl+H show/hide sketchy + nsfw (blurred again every time the picker opens)
// · Enter or click apply · Esc or click outside close.
PanelWindow {
    id: root
    readonly property bool open: Ui.wallpapers
    readonly property string home: Quickshell.env("HOME")
    readonly property string wallDir: home + "/Pictures/Wallpapers"
    readonly property string thumbDir: home + "/.cache/wallthumbs"
    readonly property string script: home + "/.config/hypr/scripts/theme.sh"

    property var walls: []        // { path, name, folder, thumb }
    property string current: ""
    property string mode: "dark"  // theme-state line 2
    property string folder: ""    // "" = all
    property bool previewing: false
    property bool reveal: false
    function hidden(w) { return !reveal && (w?.folder === "sketchy" || w?.folder === "nsfw") }
    readonly property var folders: [""].concat([...new Set(walls.map(w => w.folder))].filter(f => f).sort())

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    WlrLayershell.namespace: "quickshell:wallpapers"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: false

    onOpenChanged: {
        if (open) {
            hideTimer.stop()
            search.text = ""
            previewing = false
            reveal = false
            scan.running = true
            visible = true
            search.forceActiveFocus()
        } else hideTimer.restart()
    }
    Timer { id: hideTimer; interval: Theme.anim; onTriggered: root.visible = false }

    // list wallpapers (same folders as theme.sh) and make thumbnails we don't have yet
    Process {
        id: scan
        command: ["bash", "-c", `
            dir="$1"; thumbs="$2"; mkdir -p "$thumbs"
            sed -n 1p "$HOME/.cache/theme-state" 2>/dev/null | sed 's/^/@/'
            sed -n 2p "$HOME/.cache/theme-state" 2>/dev/null | sed 's/^/#/'
            find "$dir" -maxdepth 2 -path '*/.colors' -prune -o -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \\) -print | sort |
            while IFS= read -r f; do
                t="$thumbs/$(printf '%s' "$f" | md5sum | cut -c1-32).jpg"
                [ "$t" -nt "$f" ] || vipsthumbnail "$f" -s 480x270 -m centre --path "$t[Q=85]" 2>/dev/null
                printf '%s\\t%s\\n' "$f" "$t"
            done`, "bash", root.wallDir, root.thumbDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l)
                const cur = lines.find(l => l.startsWith("@"))
                root.current = cur ? cur.slice(1) : ""
                const mode = lines.find(l => l.startsWith("#"))
                root.mode = mode === "#light" ? "light" : "dark"
                root.walls = lines.filter(l => !/^[@#]/.test(l)).map(l => {
                    const [path, thumb] = l.split("\t")
                    const rel = path.slice(root.wallDir.length + 1)
                    const slash = rel.indexOf("/")
                    return { path, thumb: "file://" + thumb, name: rel.slice(slash + 1), folder: slash > 0 ? rel.slice(0, slash) : "" }
                })
                grid.currentIndex = Math.max(0, root.results.findIndex(w => w.path === root.current))
                grid.positionViewAtIndex(grid.currentIndex, GridView.Center)
            }
        }
    }

    readonly property var results: {
        const q = search.text.trim().toLowerCase()
        return walls.filter(w => (!folder || w.folder === folder) && (!q || w.name.toLowerCase().includes(q)))
    }

    function apply(w) {
        if (!w) return
        Quickshell.execDetached([script, "set", w.path])
        Ui.wallpapers = false
    }
    // recolors the current wallpaper; the picker stays open and follows the new colors live
    function toggleMode() {
        Quickshell.execDetached([script, "toggle-mode"])
        mode = mode === "dark" ? "light" : "dark"
    }
    function cycleFolder(step) {
        const i = folders.indexOf(folder)
        folder = folders[(i + step + folders.length) % folders.length]
        grid.currentIndex = 0
    }

    // click outside the box closes
    MouseArea {
        anchors.fill: parent
        onClicked: Ui.wallpapers = false
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
                        T { text: Icons.image; color: Theme.primary; font.pixelSize: 16 }
                        TextInput {
                            id: search
                            Layout.fillWidth: true
                            color: Theme.fg
                            selectionColor: Theme.primary
                            selectedTextColor: Theme.primaryText
                            font.family: Theme.font
                            font.pixelSize: 14
                            clip: true
                            onTextChanged: grid.currentIndex = 0

                            T {
                                visible: !search.text
                                text: "Search wallpapers…"
                                color: Theme.alpha(Theme.fg, 0.4)
                                font.pixelSize: 14
                                font.weight: Font.Normal
                            }

                            Keys.onPressed: e => {
                                if (e.key === Qt.Key_Escape && root.previewing) root.previewing = false
                                else if (e.key === Qt.Key_Escape) Ui.wallpapers = false
                                else if (e.key === Qt.Key_Space && (root.previewing || search.text === "")) root.previewing = !root.previewing
                                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.apply(root.results[grid.currentIndex])
                                else if (e.key === Qt.Key_Left) grid.moveCurrentIndexLeft()
                                else if (e.key === Qt.Key_Right) grid.moveCurrentIndexRight()
                                else if (e.key === Qt.Key_Up) grid.moveCurrentIndexUp()
                                else if (e.key === Qt.Key_Down) grid.moveCurrentIndexDown()
                                else if (e.key === Qt.Key_D && (e.modifiers & Qt.ControlModifier)) root.toggleMode()
                                else if (e.key === Qt.Key_H && (e.modifiers & Qt.ControlModifier)) root.reveal = !root.reveal
                                else if (e.key === Qt.Key_Tab) root.cycleFolder(1)
                                else if (e.key === Qt.Key_Backtab) root.cycleFolder(-1)
                                else return
                                e.accepted = true
                            }
                        }
                        T { text: root.results.length; color: Theme.fgDim; font.pixelSize: 11 }
                    }
                }

                // folder chips
                Repeater {
                    model: root.folders
                    delegate: Rectangle {
                        id: chip
                        required property string modelData
                        readonly property bool on: root.folder === modelData
                        implicitWidth: chipText.implicitWidth + 24
                        implicitHeight: 38
                        radius: Theme.radius
                        color: on ? Theme.primary : cm.containsMouse ? Theme.alpha(Theme.secondary, 0.9) : Theme.alpha(Theme.secondary, 0.4)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        T {
                            id: chipText
                            anchors.centerIn: parent
                            text: chip.modelData || "all"
                            color: chip.on ? Theme.primaryText : Theme.fg
                        }
                        MouseArea {
                            id: cm
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.folder = chip.modelData; grid.currentIndex = 0; search.forceActiveFocus() }
                        }
                    }
                }

                // light / dark
                Rectangle {
                    implicitWidth: modeRow.implicitWidth + 24
                    implicitHeight: 38
                    radius: Theme.radius
                    color: mm.containsMouse ? Theme.alpha(Theme.tertiary, 0.9) : Theme.alpha(Theme.tertiary, 0.25)
                    Behavior on color { ColorAnimation { duration: 150 } }
                    RowLayout {
                        id: modeRow
                        anchors.centerIn: parent
                        spacing: 8
                        T { text: root.mode === "dark" ? Icons.moon : Icons.sun; font.pixelSize: 15; color: mm.containsMouse ? Theme.tertiaryText : Theme.fg }
                        T { text: root.mode; color: mm.containsMouse ? Theme.tertiaryText : Theme.fg }
                    }
                    MouseArea {
                        id: mm
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { root.toggleMode(); search.forceActiveFocus() }
                    }
                }

                // show / hide sketchy + nsfw
                Rectangle {
                    implicitWidth: 38
                    implicitHeight: 38
                    radius: Theme.radius
                    color: rm.containsMouse || root.reveal ? Theme.alpha(Theme.error, 0.9) : Theme.alpha(Theme.secondary, 0.4)
                    Behavior on color { ColorAnimation { duration: 150 } }
                    T { anchors.centerIn: parent; text: root.reveal ? Icons.eye : Icons.eyeOff; font.pixelSize: 15; color: rm.containsMouse || root.reveal ? Theme.errorText : Theme.fg }
                    MouseArea {
                        id: rm
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { root.reveal = !root.reveal; search.forceActiveFocus() }
                    }
                }
            }

            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: Math.floor(width / 4)
                cellHeight: Math.floor(cellWidth * 9 / 16) + 26
                model: ScriptModel { values: root.results }
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 120
                WheelScroll { view: grid }

                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property bool current: GridView.isCurrentItem
                    readonly property bool active: modelData.path === root.current
                    width: grid.cellWidth
                    height: grid.cellHeight

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 4

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 10
                            color: cell.current ? Theme.primary : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }

                            ClippingRectangle {
                                anchors.fill: parent
                                anchors.margins: 3
                                radius: 8
                                color: Theme.alpha(Theme.secondary, 0.8)
                                Image {
                                    anchors.fill: parent
                                    source: cell.modelData.thumb
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    scale: cell.current ? 1.04 : 1
                                    Behavior on scale { NumberAnimation { duration: 150 } }
                                    layer.enabled: root.hidden(cell.modelData)
                                    layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 64; brightness: -0.1 }
                                }
                                T {
                                    visible: root.hidden(cell.modelData)
                                    anchors.centerIn: parent
                                    text: `${Icons.eyeOff}  ${cell.modelData.folder}`
                                    color: Theme.fg
                                }
                            }

                            // badge on the wallpaper in use
                            Rectangle {
                                visible: cell.active
                                anchors { top: parent.top; right: parent.right; margins: 9 }
                                width: 22; height: 22; radius: 11
                                color: Theme.primary
                                T { anchors.centerIn: parent; text: Icons.check; color: Theme.primaryText; font.pixelSize: 13 }
                            }
                        }
                        T {
                            Layout.fillWidth: true
                            text: cell.modelData.name
                            elide: Text.ElideMiddle
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: 11
                            font.weight: Font.Normal
                            color: cell.current ? Theme.fg : Theme.fgDim
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: if (!root.previewing) grid.currentIndex = cell.index   // preview covers the grid; hover must not change it
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: e => {
                            if (e.button === Qt.RightButton) root.previewing = true
                            else root.apply(cell.modelData)
                        }
                    }
                }

                T {
                    anchors.centerIn: parent
                    visible: root.results.length === 0
                    text: scan.running ? "Making thumbnails…" : root.walls.length ? "No matches" : "No wallpapers in " + root.wallDir
                    color: Theme.alpha(Theme.fg, 0.4)
                }
            }

            T {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: "Enter / click apply · Space / right-click preview · Tab folder · Ctrl+D light/dark · Ctrl+H show sketchy/nsfw · Esc close"
                color: Theme.alpha(Theme.fg, 0.4)
                font.pixelSize: 11
                font.weight: Font.Normal
            }
        }

        // full-size preview of the selected wallpaper
        ClippingRectangle {
            id: preview
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius
            color: Theme.bg
            visible: opacity > 0
            opacity: root.previewing ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }
            readonly property var w: root.results[grid.currentIndex] ?? null

            Image {
                anchors.fill: parent
                source: root.previewing && preview.w ? "file://" + preview.w.path : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(width, height)
                layer.enabled: root.hidden(preview.w)
                layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 64; brightness: -0.1 }
            }
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: 18
                width: label.implicitWidth + 30
                height: 36
                radius: 18
                color: Theme.popup
                T {
                    id: label
                    anchors.centerIn: parent
                    text: `${preview.w?.name ?? ""}   ·   Enter apply · ←→ next${root.hidden(preview.w) ? " · Ctrl+H unblur" : ""} · Space back`
                }
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: e => {
                    if (e.button === Qt.RightButton) root.previewing = false
                    else root.apply(preview.w)
                }
            }
        }
    }
}
