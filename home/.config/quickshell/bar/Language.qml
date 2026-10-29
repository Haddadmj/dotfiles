import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs
import qs.components

// Keyboard layout with a flag. Follows Hyprland's activelayout event.
Island {
    id: root
    property string layout: ""

    readonly property var known: [
        { prefix: "English", flag: "🇺🇸", code: "EN" },
        { prefix: "Arabic",  flag: "🇸🇦", code: "AR" },
    ]
    readonly property var current: known.find(k => layout.startsWith(k.prefix))
                                   ?? { flag: "⌨", code: layout.slice(0, 2).toUpperCase() }

    clickable: true
    onClicked: Quickshell.execDetached(["hyprctl", "switchxkblayout", "current", "next"])

    T { text: `${root.current.flag}  ${root.current.code}` }

    Process {
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const kbs = JSON.parse(text).keyboards
                root.layout = (kbs.find(k => k.main) ?? kbs[0]).active_keymap
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout") root.layout = event.data.slice(event.data.indexOf(",") + 1)
        }
    }

    Tip {
        target: root
        show: root.hovered
        text: `${root.layout}<br><font color='${Theme.fgDim}'>Caps Lock or click to switch</font>`
    }
}
