import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.components

// Autostart tab of the Hyprland settings panel. Lists the start("…") lines of
// modules/autostart.lua (switch them off) plus your own commands. Takes effect at next login;
// ▶ runs a command now.
ColumnLayout {
    id: root
    required property var panel
    spacing: 4

    FileView { id: file; path: root.panel.hypr + "/modules/autostart.lua"; watchChanges: true; onFileChanged: reload() }
    readonly property var builtins: file.text().split("\n")
        .map(l => l.match(/^\s*start\("((?:[^"\\]|\\.)*)"\)\s*(?:--\s*(.*))?$/))
        .filter(m => m)
        .map(m => ({ cmd: m[1].replace(/\\(.)/g, "$1"), note: m[2] ?? "" }))

    component Entry: RowLayout {
        id: e
        property string cmd
        property string note
        property bool on: true
        property bool custom: false
        Layout.fillWidth: true
        Layout.preferredHeight: 34
        spacing: 10
        Switch {
            visible: !e.custom
            checked: e.on
            onToggled: root.panel.update(c => {
                c.disabledAutostart = e.on ? [...c.disabledAutostart, e.cmd] : c.disabledAutostart.filter(x => x !== e.cmd)
            }, false)
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            T { Layout.fillWidth: true; text: e.cmd; elide: Text.ElideMiddle; font.pixelSize: 12; color: e.on ? Theme.fg : Theme.fgDim }
            T { visible: e.note !== ""; Layout.fillWidth: true; text: e.note; elide: Text.ElideRight; font.pixelSize: 11; font.weight: Font.Normal; color: Theme.fgDim }
        }
        Pill { icon: Icons.play; onClicked: root.panel.run(e.cmd) }
        Pill {
            visible: e.custom
            icon: Icons.trash
            danger: true
            onClicked: root.panel.update(c => { c.autostart = c.autostart.filter(x => x !== e.cmd) }, false)
        }
    }

    T {
        Layout.fillWidth: true
        text: "Runs at login · switches take effect next login · ▶ runs it now"
        color: Theme.alpha(Theme.fg, 0.45)
        font.pixelSize: 11
        font.weight: Font.Normal
    }
    T { text: "From autostart.lua"; color: Theme.primary; Layout.topMargin: 8 }
    Repeater {
        model: root.builtins
        Entry {
            required property var modelData
            cmd: modelData.cmd
            note: modelData.note
            on: !root.panel.cfg.disabledAutostart.includes(modelData.cmd)
        }
    }

    T { text: "Your commands"; color: Theme.primary; Layout.topMargin: 14 }
    T { visible: root.panel.cfg.autostart.length === 0; text: "None yet"; color: Theme.fgDim; font.pixelSize: 12; font.weight: Font.Normal }
    Repeater {
        model: root.panel.cfg.autostart
        Entry { required property string modelData; cmd: modelData; custom: true }
    }
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 6
        spacing: 6
        Field { id: newCmd; Layout.fillWidth: true; placeholder: "command, e.g. discord --start-minimized"; onAccepted: add.clicked() }
        Pill {
            id: add
            icon: Icons.plus
            text: "Add"
            implicitHeight: 30
            onClicked: {
                const cmd = newCmd.text.trim()
                if (!cmd || root.panel.cfg.autostart.includes(cmd)) return
                root.panel.update(c => c.autostart.push(cmd), false)
                newCmd.text = ""
            }
        }
    }
}
