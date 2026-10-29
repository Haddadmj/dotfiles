import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.components

// Environment tab of the Hyprland settings panel. Shows the hl.env("NAME", "value") lines of
// modules/env.lua (edit the value; Enter saves) plus your own variables. Applies to apps
// started afterwards; things started at login (D-Bus/systemd services) need a re-login.
ColumnLayout {
    id: root
    required property var panel
    spacing: 4

    FileView { id: file; path: root.panel.hypr + "/modules/env.lua"; watchChanges: true; onFileChanged: reload() }
    readonly property var builtins: file.text().split("\n")
        .map(l => l.match(/^\s*hl\.env\("([^"]+)",\s*"([^"]*)"\)\s*(?:--\s*(.*))?$/))
        .filter(m => m)
        .map(m => ({ name: m[1], value: m[2], note: m[3] ?? "" }))
    readonly property var custom: Object.keys(panel.cfg.env).filter(n => !builtins.find(b => b.name === n))

    function setVar(name, value) { panel.update(c => { c.env[name] = value }, true) }
    function unset(name) { panel.update(c => { delete c.env[name] }, true) }

    component Var: RowLayout {
        id: v
        property string name
        property string fileValue
        property string note
        property bool custom: false
        readonly property string value: root.panel.cfg.env[name] ?? fileValue
        readonly property bool modified: !custom && root.panel.cfg.env[name] !== undefined
        Layout.fillWidth: true
        Layout.preferredHeight: 34
        spacing: 10
        onValueChanged: f.text = value      // the field's binding breaks once typed in
        Dot { visible: !v.custom; modified: v.modified; onReset: root.unset(v.name) }
        ColumnLayout {
            Layout.preferredWidth: 230
            spacing: 0
            T { Layout.fillWidth: true; text: v.name; elide: Text.ElideRight; font.pixelSize: 12 }
            T { visible: v.note !== ""; Layout.fillWidth: true; text: v.note; elide: Text.ElideRight; font.pixelSize: 11; font.weight: Font.Normal; color: Theme.fgDim }
        }
        Field {
            id: f
            Layout.fillWidth: true
            text: v.value
            onAccepted: if (text !== v.value) root.setVar(v.name, text)
            onEscaped: text = v.value
        }
        Pill { visible: v.custom; icon: Icons.trash; danger: true; onClicked: root.unset(v.name) }
    }

    T {
        Layout.fillWidth: true
        text: "Enter saves · ● changed, click to reset · applies to apps started afterwards (some need a re-login)"
        color: Theme.alpha(Theme.fg, 0.45)
        font.pixelSize: 11
        font.weight: Font.Normal
        wrapMode: Text.WordWrap
    }
    T { text: "From env.lua"; color: Theme.primary; Layout.topMargin: 8 }
    Repeater {
        model: root.builtins
        Var { required property var modelData; name: modelData.name; fileValue: modelData.value; note: modelData.note }
    }

    T { text: "Your variables"; color: Theme.primary; Layout.topMargin: 14 }
    T { visible: root.custom.length === 0; text: "None yet"; color: Theme.fgDim; font.pixelSize: 12; font.weight: Font.Normal }
    Repeater {
        model: root.custom
        Var { required property string modelData; name: modelData; custom: true }
    }
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 6
        spacing: 6
        Field { id: newName; Layout.preferredWidth: 230; placeholder: "NAME"; invalid: text !== "" && !/^[A-Za-z_][A-Za-z0-9_]*$/.test(text); onAccepted: newValue.takeFocus() }
        Field { id: newValue; Layout.fillWidth: true; placeholder: "value"; onAccepted: add.clicked() }
        Pill {
            id: add
            icon: Icons.plus
            text: "Add"
            implicitHeight: 30
            onClicked: {
                if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(newName.text)) return
                root.setVar(newName.text, newValue.text)
                newName.text = ""; newValue.text = ""
            }
        }
    }
}
