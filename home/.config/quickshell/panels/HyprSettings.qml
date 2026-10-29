import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components

// Hyprland settings (SUPER+,): look & input options, keybinds, autostart, environment.
// Everything is saved to ~/.config/hypr/settings.json (format: ~/.config/hypr/modules/settings.lua);
// the .lua modules read it, so the hand-written config files are never edited.
// Options apply live via `hyprctl repl`; binds/env reload the config.
PanelWindow {
    id: root
    readonly property bool open: Ui.hyprSettings
    readonly property string hypr: Quickshell.env("HOME") + "/.config/hypr"
    property var cfg: emptyCfg()
    property var values: ({})        // option -> current value

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    WlrLayershell.namespace: "quickshell:hyprsettings"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: false

    signal reloaded()

    onOpenChanged: {
        if (open) { hideTimer.stop(); load(); reader.running = true; visible = true; box.forceActiveFocus() }
        else hideTimer.restart()
    }
    Timer { id: hideTimer; interval: Theme.anim; onTriggered: root.visible = false }

    // ── settings.json ─────────────────────────────────
    function emptyCfg() { return { options: {}, binds: [], remap: {}, disabledBinds: [], env: {}, autostart: [], disabledAutostart: [] } }
    FileView { id: store; path: root.hypr + "/settings.json"; blockLoading: true; printErrors: false }
    function load() {
        store.reload()
        let c = {}
        try { c = JSON.parse(store.text() || "{}") } catch (e) {}
        root.cfg = Object.assign(emptyCfg(), c)
    }
    // mutate(copy) edits a copy of cfg; reload: re-run the Hyprland config afterwards
    function update(mutate, reload) {
        const c = JSON.parse(JSON.stringify(cfg))
        mutate(c)
        cfg = c
        store.setText(JSON.stringify(c, null, 2) + "\n")
        if (reload) reloadTimer.restart()
    }
    Timer {
        id: reloadTimer
        interval: 300
        onTriggered: { Quickshell.execDetached(["hyprctl", "reload", "config-only"]); afterReload.restart() }
    }
    Timer { id: afterReload; interval: 500; onTriggered: { reader.running = true; root.reloaded() } }

    function run(cmd) { Quickshell.execDetached(["sh", "-c", cmd]) }

    // ── look & input options ──────────────────────────
    // type: int / float (min, max, step) · bool · choice (options: [[value, label]…])
    readonly property var sections: [
        { title: "Gaps & borders", items: [
            { key: "general:gaps_in", label: "Inner gaps", type: "int", min: 0, max: 30 },
            { key: "general:gaps_out", label: "Outer gaps", type: "int", min: 0, max: 60 },
            { key: "general:border_size", label: "Border size", type: "int", min: 0, max: 10 },
            { key: "decoration:rounding", label: "Corner rounding", type: "int", min: 0, max: 30 },
            { key: "general:resize_on_border", label: "Resize by dragging borders", type: "bool" },
        ] },
        { title: "Effects", items: [
            { key: "animations:enabled", label: "Animations", type: "bool" },
            { key: "decoration:blur:enabled", label: "Blur", type: "bool" },
            { key: "decoration:blur:size", label: "Blur size", type: "int", min: 1, max: 20 },
            { key: "decoration:blur:passes", label: "Blur passes", type: "int", min: 1, max: 6 },
            { key: "decoration:shadow:enabled", label: "Shadows", type: "bool" },
            { key: "decoration:active_opacity", label: "Focused window opacity", type: "float", min: 0.3, max: 1, step: 0.05 },
            { key: "decoration:inactive_opacity", label: "Unfocused window opacity", type: "float", min: 0.3, max: 1, step: 0.05 },
            { key: "decoration:dim_inactive", label: "Dim unfocused windows", type: "bool" },
        ] },
        { title: "Layout", items: [
            { key: "general:layout", label: "Tiling layout", type: "choice", options: [["dwindle", "Dwindle"], ["master", "Master"]] },
        ] },
        { title: "Mouse & keyboard", items: [
            { key: "input:sensitivity", label: "Mouse sensitivity", type: "float", min: -1, max: 1, step: 0.05 },
            { key: "input:accel_profile", label: "Acceleration", type: "choice", options: [["flat", "Flat"], ["adaptive", "Adaptive"]] },
            { key: "input:follow_mouse", label: "Focus follows mouse", type: "choice", options: [[0, "Off"], [1, "Always"], [2, "Click"], [3, "Hover"]] },
            { key: "input:touchpad:natural_scroll", label: "Natural scroll (touchpad)", type: "bool" },
            { key: "input:repeat_rate", label: "Key repeat rate", type: "int", min: 10, max: 80 },
            { key: "input:repeat_delay", label: "Key repeat delay (ms)", type: "int", min: 150, max: 1000, step: 25 },
        ] },
        { title: "Misc", items: [
            { key: "misc:vrr", label: "Adaptive sync (VRR)", type: "choice", options: [[0, "Off"], [1, "On"], [2, "Fullscreen"]] },
            { key: "cursor:inactive_timeout", label: "Hide idle cursor (s, 0 = never)", type: "int", min: 0, max: 30 },
        ] },
    ]
    readonly property var allKeys: [].concat(...sections.map(s => s.items.map(i => i.key)))

    Process {
        id: reader
        command: ["bash", "-c", 'for k; do hyprctl getoption "$k" -j | tr -d "\\n"; echo; done', "bash", ...root.allKeys]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = {}
                for (const line of text.trim().split("\n")) {
                    try {
                        const o = JSON.parse(line)
                        v[o.option] = o.int ?? o.float ?? o.bool ?? o.str ?? (o.css !== undefined ? Number(o.css.split(" ")[0]) : undefined)
                    } catch (e) {}
                }
                root.values = v
            }
        }
    }

    function lua(key, value) {
        const parts = key.split(":")
        let s = typeof value === "string" ? JSON.stringify(value) : String(value)
        for (let i = parts.length - 1; i >= 0; i--) s = `{ ${parts[i]} = ${s} }`
        return `hl.config(${s})`
    }
    property var pending: ({})
    function setOption(key, value) {
        values = Object.assign({}, values, { [key]: value })
        pending[key] = value
        applyTimer.restart()
    }
    Timer {
        id: applyTimer
        interval: 120
        onTriggered: {
            const p = root.pending
            root.pending = {}
            Quickshell.execDetached(["hyprctl", "repl", Object.keys(p).map(k => root.lua(k, p[k])).join("; ")])
            root.update(c => Object.assign(c.options, p), false)
        }
    }
    // drop overrides and reload so the values from the .lua files come back
    function resetOptions(keys) { update(c => { for (const k of keys) delete c.options[k] }, true) }

    MouseArea { anchors.fill: parent; onClicked: Ui.hyprSettings = false }

    component Setting: RowLayout {
        id: row
        required property var modelData
        readonly property var item: modelData
        readonly property var value: root.values[item.key]
        readonly property bool changed: root.cfg.options[item.key] !== undefined
        Layout.fillWidth: true
        Layout.preferredHeight: 34
        spacing: 10

        Dot { modified: row.changed; onReset: root.resetOptions([row.item.key]) }
        T { Layout.fillWidth: true; text: row.item.label; elide: Text.ElideRight; font.weight: Font.Normal }

        Slider {
            visible: row.item.type === "int" || row.item.type === "float"
            Layout.preferredWidth: 170
            max: (row.item.max ?? 1) - (row.item.min ?? 0)
            value: (Number(row.value) || 0) - (row.item.min ?? 0)
            onMoved: v => {
                const step = row.item.step ?? 1
                let n = Math.round((v + row.item.min) / step) * step
                n = row.item.type === "int" ? Math.round(n) : Math.round(n * 100) / 100
                if (n !== row.value) root.setOption(row.item.key, n)
            }
        }
        T {
            visible: row.item.type === "int" || row.item.type === "float"
            Layout.preferredWidth: 40
            horizontalAlignment: Text.AlignRight
            text: row.value === undefined ? "…" : row.item.type === "float" ? Number(row.value).toFixed(2) : row.value
            color: Theme.fgDim
        }
        Switch {
            visible: row.item.type === "bool"
            checked: !!row.value
            onToggled: root.setOption(row.item.key, !row.value)
        }
        Row {
            visible: row.item.type === "choice"
            spacing: 4
            Repeater {
                model: row.item.options ?? []
                Pill {
                    required property var modelData
                    text: modelData[1]
                    on: row.value === modelData[0]
                    onClicked: root.setOption(row.item.key, modelData[0])
                }
            }
        }
    }

    // ── panel ─────────────────────────────────────────
    Rectangle {
        id: box
        anchors.centerIn: parent
        width: 680
        height: Math.min(760, root.height - 80)
        radius: Theme.radius + 4
        color: Theme.popup
        border.width: 1
        border.color: Theme.alpha(Theme.primary, 0.35)
        clip: true
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
        Keys.onEscapePressed: Ui.hyprSettings = false
        MouseArea { anchors.fill: parent; onClicked: box.forceActiveFocus() }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                T { text: `${Icons.settings}  Hyprland`; color: Theme.primary; font.pixelSize: 16; Layout.fillWidth: true }
                Repeater {
                    model: [["look", "Look & input"], ["binds", "Keybinds"], ["autostart", "Autostart"], ["env", "Environment"]]
                    Pill {
                        required property var modelData
                        text: modelData[1]
                        on: Ui.hyprSettingsTab === modelData[0]
                        implicitHeight: 30
                        onClicked: Ui.hyprSettingsTab = modelData[0]
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.islandBorder }

            Flickable {
                id: flick
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: page.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                WheelScroll { view: flick }

                ColumnLayout {
                    id: page
                    width: flick.width

                    // look & input
                    ColumnLayout {
                        visible: Ui.hyprSettingsTab === "look"
                        Layout.fillWidth: true
                        spacing: 4
                        RowLayout {
                            Layout.fillWidth: true
                            T {
                                Layout.fillWidth: true
                                text: "Changes apply right away · ● changed, click to reset"
                                color: Theme.alpha(Theme.fg, 0.45)
                                font.pixelSize: 11
                                font.weight: Font.Normal
                            }
                            Pill {
                                visible: Object.keys(root.cfg.options).length > 0
                                icon: Icons.undo
                                text: "Reset all"
                                onClicked: root.resetOptions(Object.keys(root.cfg.options))
                            }
                        }
                        Repeater {
                            model: root.sections
                            ColumnLayout {
                                id: sec
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.topMargin: 8
                                spacing: 0
                                T { text: sec.modelData.title; color: Theme.primary; font.pixelSize: 12; Layout.bottomMargin: 4 }
                                Repeater { model: sec.modelData.items; Setting {} }
                            }
                        }
                    }

                    HyprBinds { visible: Ui.hyprSettingsTab === "binds"; panel: root; Layout.fillWidth: true }
                    HyprAutostart { visible: Ui.hyprSettingsTab === "autostart"; panel: root; Layout.fillWidth: true }
                    HyprEnv { visible: Ui.hyprSettingsTab === "env"; panel: root; Layout.fillWidth: true }
                }
            }
        }
    }
}
