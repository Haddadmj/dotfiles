import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components

// Keybind cheat sheet (SUPER+/). Lists every Hyprland bind that has a description,
// read live from `hyprctl binds -j`, so it follows modules/keybinds.lua.
// Description format there: "Group|What it does" or "Group|What it does|key label".
// Type to filter · Esc closes.
PanelWindow {
    id: root
    readonly property bool open: Ui.cheatsheet
    property var groups: []          // [{ name, binds: [{ keys, text }] }]
    property string query: ""

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    WlrLayershell.namespace: "quickshell:cheatsheet"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: false

    onOpenChanged: {
        if (open) { hideTimer.stop(); query = ""; search.text = ""; binds.running = true; visible = true; search.forceActiveFocus() }
        else hideTimer.restart()
    }
    Timer { id: hideTimer; interval: Theme.anim; onTriggered: root.visible = false }

    readonly property var keyNames: ({
        Return: "Enter", period: ".", comma: ",", slash: "/", left: "←", right: "→", up: "↑", down: "↓",
        mouse_down: "scroll ↓", mouse_up: "scroll ↑", "mouse:272": "left drag", "mouse:273": "right drag", Tab: "Tab"
    })
    function keyLabel(b) {
        const mods = [[64, "SUPER"], [4, "CTRL"], [8, "ALT"], [1, "SHIFT"]].filter(m => b.modmask & m[0]).map(m => m[1])
        return [...mods, keyNames[b.key] ?? b.key].join(" + ")
    }

    Process {
        id: binds
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                for (const b of JSON.parse(text)) {
                    if (!b.description) continue
                    const [group, desc, keys] = b.description.split("|")
                    let g = out.find(x => x.name === group)
                    if (!g) out.push(g = { name: group, binds: [] })
                    g.binds.push({ keys: keys ?? root.keyLabel(b), text: desc ?? group })
                }
                root.groups = out
            }
        }
    }

    readonly property var shown: {
        const q = query.toLowerCase()
        if (!q) return groups
        return groups.map(g => ({ name: g.name, binds: g.binds.filter(b =>
            `${g.name} ${b.text} ${b.keys}`.toLowerCase().includes(q)) })).filter(g => g.binds.length)
    }

    MouseArea { anchors.fill: parent; onClicked: Ui.cheatsheet = false }
    Rectangle { anchors.fill: parent; color: Theme.alpha(Theme.bg, root.open ? 0.35 : 0); Behavior on color { ColorAnimation { duration: Theme.anim } } }

    Rectangle {
        id: box
        anchors.centerIn: parent
        width: Math.min(1120, root.width - 80)
        height: Math.min(col.implicitHeight + 40, root.height - 80)
        radius: Theme.radius + 4
        color: Theme.popup
        border.width: 1
        border.color: Theme.alpha(Theme.primary, 0.35)
        clip: true
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent }

        Flickable {
            id: cheatFlick
            anchors.fill: parent
            anchors.margins: 20
            contentHeight: col.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            WheelScroll { view: cheatFlick }

            ColumnLayout {
                id: col
                width: parent.width
                spacing: 16

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    T { text: `${Icons.keyboard}  Keybinds`; color: Theme.primary; font.pixelSize: 16 }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        implicitWidth: 260; implicitHeight: 32; radius: Theme.radius
                        color: Theme.alpha(Theme.secondary, 0.5)
                        TextInput {
                            id: search
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            selectionColor: Theme.primary
                            onTextChanged: root.query = text
                            Keys.onEscapePressed: Ui.cheatsheet = false
                        }
                        T {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 12
                            visible: search.text === ""
                            text: "Filter…"
                            color: Theme.alpha(Theme.fg, 0.4)
                            font.weight: Font.Normal
                        }
                    }
                }

                T { visible: root.shown.length === 0; text: "No matching binds"; color: Theme.fgDim }

                GridLayout {
                    Layout.fillWidth: true
                    columns: Math.max(1, Math.floor(box.width / 360))
                    columnSpacing: 28
                    rowSpacing: 18

                    Repeater {
                        model: root.shown
                        ColumnLayout {
                            id: group
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.alignment: Qt.AlignTop
                            spacing: 6

                            T { text: group.modelData.name; color: Theme.primary }
                            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.islandBorder }
                            Repeater {
                                model: group.modelData.binds
                                RowLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 10
                                    T {
                                        Layout.fillWidth: true
                                        text: modelData.text
                                        elide: Text.ElideRight
                                        font.weight: Font.Normal
                                    }
                                    Row {
                                        spacing: 4
                                        Repeater {
                                            model: modelData.keys.split(" + ")
                                            Rectangle {
                                                required property string modelData
                                                implicitWidth: k.implicitWidth + 12
                                                implicitHeight: 22
                                                radius: 5
                                                color: Theme.alpha(Theme.secondary, 0.7)
                                                border.width: 1
                                                border.color: Theme.islandBorder
                                                T { id: k; anchors.centerIn: parent; text: parent.modelData; font.pixelSize: 11 }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
