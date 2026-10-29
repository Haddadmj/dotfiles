import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs
import qs.components

// Keybinds tab of the Hyprland settings panel. Binds with a description in keybinds.lua can be
// re-keyed (click the keys) or switched off; custom binds run a command. Stored in settings.json.
ColumnLayout {
    id: root
    required property var panel
    property var all: []            // every bind: { desc, mask, key }
    property string editing: ""     // description of the bind being re-keyed
    property string error: ""
    spacing: 4

    onVisibleChanged: if (visible) list.running = true
    Connections { target: root.panel; function onReloaded() { list.running = true } }

    Process {
        id: list
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.all = JSON.parse(text).map(b => ({ desc: b.description, mask: b.modmask, key: b.key })) } catch (e) {}
            }
        }
    }

    readonly property var mods: [[64, "SUPER"], [4, "CTRL"], [8, "ALT"], [1, "SHIFT"]]
    function keysText(b) { return [...mods.filter(m => b.mask & m[0]).map(m => m[1]), b.key].join(" + ") }
    // "super+shift + t" -> { mask, key, text } or null
    function parse(str) {
        const parts = str.split("+").map(s => s.trim()).filter(s => s)
        if (!parts.length) return null
        const aliases = { CONTROL: "CTRL", WIN: "SUPER", MOD4: "SUPER", META: "SUPER" }
        let mask = 0
        for (const p of parts.slice(0, -1)) {
            const m = mods.find(x => x[1] === (aliases[p.toUpperCase()] ?? p.toUpperCase()))
            if (!m) return null
            mask |= m[0]
        }
        const key = parts[parts.length - 1]
        return { mask, key, text: keysText({ mask, key }) }
    }
    function usedBy(p, except) {
        const b = all.find(b => b.mask === p.mask && b.key.toLowerCase() === p.key.toLowerCase() && b.desc !== except)
        return b ? (b.desc ? b.desc.split("|")[1] : "another bind") : ""
    }

    // built-in binds from keybinds.lua, including switched-off ones (those aren't registered)
    readonly property var builtins: {
        const out = all.filter(b => b.desc && !b.desc.startsWith("Custom|"))
            .map(b => ({ desc: b.desc, keys: b.desc.split("|")[2] ?? keysText(b), fixed: b.desc.split("|").length > 2, on: true }))
        for (const d of panel.cfg.disabledBinds)
            if (!out.find(b => b.desc === d)) out.push({ desc: d, keys: panel.cfg.remap[d] ?? "", fixed: d.split("|").length > 2, on: false })
        // keep each group together, in order of first appearance
        const groups = [...new Set(out.map(b => b.desc.split("|")[0]))]
        return out.map((b, i) => [b, i]).sort((x, y) => groups.indexOf(x[0].desc.split("|")[0]) - groups.indexOf(y[0].desc.split("|")[0]) || x[1] - y[1]).map(x => x[0])
    }

    function rekey(desc, text) {
        const p = parse(text)
        if (!p) { error = `"${text}" isn't a valid key combo, e.g. SUPER + SHIFT + T`; return }
        const other = usedBy(p, desc)
        if (other) { error = `${p.text} is already used by "${other}"`; return }
        error = ""; editing = ""
        panel.update(c => { c.remap[desc] = p.text }, true)
    }

    T {
        Layout.fillWidth: true
        text: "Click keys to change them · ● changed, click to reset · switched-off binds stay listed"
        color: Theme.alpha(Theme.fg, 0.45)
        font.pixelSize: 11
        font.weight: Font.Normal
        wrapMode: Text.WordWrap
    }
    T { visible: root.error !== ""; Layout.fillWidth: true; text: root.error; color: Theme.error; font.pixelSize: 12; wrapMode: Text.WordWrap }

    component KeyChips: Row {
        id: kc
        property string keys
        property bool dim: false
        spacing: 4
        Repeater {
            model: kc.keys ? kc.keys.split(" + ") : []
            Rectangle {
                required property string modelData
                implicitWidth: kt.implicitWidth + 12
                implicitHeight: 22
                radius: 5
                color: Theme.alpha(Theme.secondary, kc.dim ? 0.3 : 0.7)
                border.width: 1
                border.color: Theme.islandBorder
                T { id: kt; anchors.centerIn: parent; text: parent.modelData; font.pixelSize: 11; color: kc.dim ? Theme.fgDim : Theme.fg }
            }
        }
    }

    // ── built-in ──────────────────────────────────────
    Repeater {
        model: root.builtins
        RowLayout {
            id: row
            required property var modelData
            required property int index
            readonly property var parts: modelData.desc.split("|")
            readonly property bool remapped: root.panel.cfg.remap[modelData.desc] !== undefined
            readonly property bool newGroup: index === 0 || root.builtins[index - 1].desc.split("|")[0] !== parts[0]
            Layout.fillWidth: true
            Layout.topMargin: newGroup ? 10 : 0
            Layout.preferredHeight: 32
            spacing: 10

            Switch {
                checked: row.modelData.on
                onToggled: root.panel.update(c => {
                    const d = row.modelData.desc
                    c.disabledBinds = row.modelData.on ? [...c.disabledBinds, d] : c.disabledBinds.filter(x => x !== d)
                }, true)
            }
            T { Layout.preferredWidth: 96; text: row.newGroup ? row.parts[0] : ""; color: Theme.primary; font.pixelSize: 12 }
            T {
                Layout.fillWidth: true
                text: row.parts[1]
                elide: Text.ElideRight
                font.weight: Font.Normal
                color: row.modelData.on ? Theme.fg : Theme.fgDim
            }

            Field {
                id: field
                visible: root.editing === row.modelData.desc
                Layout.preferredWidth: 200
                placeholder: "SUPER + SHIFT + T"
                invalid: root.error !== ""
                onAccepted: root.rekey(row.modelData.desc, text)
                onEscaped: { root.editing = ""; root.error = "" }
            }
            Item {
                visible: root.editing !== row.modelData.desc
                implicitWidth: keys.implicitWidth
                implicitHeight: 22
                KeyChips { id: keys; keys: row.modelData.keys; dim: !row.modelData.on || row.modelData.fixed }
                MouseArea {
                    anchors.fill: parent
                    enabled: !row.modelData.fixed && row.modelData.on
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { root.error = ""; root.editing = row.modelData.desc; field.text = row.modelData.keys; field.takeFocus() }
                }
            }
            Dot { modified: row.remapped; onReset: root.panel.update(c => { delete c.remap[row.modelData.desc] }, true) }
        }
    }

    // ── custom ────────────────────────────────────────
    T { text: "Your binds"; color: Theme.primary; Layout.topMargin: 18 }
    T {
        visible: root.panel.cfg.binds.length === 0
        text: "None yet: add one below. It replaces anything else on the same keys."
        color: Theme.fgDim
        font.pixelSize: 12
        font.weight: Font.Normal
    }
    Repeater {
        model: root.panel.cfg.binds
        RowLayout {
            id: crow
            required property var modelData
            required property int index
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            spacing: 10
            T { Layout.preferredWidth: 150; text: crow.modelData.name || crow.modelData.cmd; elide: Text.ElideRight; font.weight: Font.Normal }
            T { Layout.fillWidth: true; text: crow.modelData.cmd; elide: Text.ElideRight; color: Theme.fgDim; font.pixelSize: 12; font.weight: Font.Normal }
            KeyChips { keys: crow.modelData.keys }
            Pill { icon: Icons.trash; danger: true; onClicked: root.panel.update(c => c.binds.splice(crow.index, 1), true) }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 6
        spacing: 6
        Field { id: newKeys; Layout.preferredWidth: 170; placeholder: "SUPER + SHIFT + T"; onAccepted: newCmd.takeFocus() }
        Field { id: newCmd; Layout.fillWidth: true; placeholder: "command, e.g. ghostty -e btop"; onAccepted: add.clicked() }
        Field { id: newName; Layout.preferredWidth: 120; placeholder: "name (optional)"; onAccepted: add.clicked() }
        Pill {
            id: add
            icon: Icons.plus
            text: "Add"
            implicitHeight: 30
            onClicked: {
                const p = root.parse(newKeys.text)
                if (!p) { root.error = "Enter keys like SUPER + SHIFT + T"; return }
                if (!newCmd.text.trim()) { root.error = "Enter a command to run"; return }
                if (root.panel.cfg.binds.find(b => root.parse(b.keys)?.text === p.text)) { root.error = `${p.text} is already one of your binds`; return }
                root.error = ""
                const b = { keys: p.text, cmd: newCmd.text.trim(), name: newName.text.trim() }
                root.panel.update(c => c.binds.push(b), true)
                newKeys.text = ""; newCmd.text = ""; newName.text = ""
            }
        }
    }
    T {
        readonly property var p: root.parse(newKeys.text)
        readonly property string other: p ? root.usedBy(p, "") : ""
        visible: other !== ""
        text: `${p?.text} is used by "${other}"; your bind will replace it`
        color: Theme.tertiary
        font.pixelSize: 11
        font.weight: Font.Normal
    }
}
