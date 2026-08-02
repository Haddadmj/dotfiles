import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Text {
    id: root

    // Hyprland exposes a keymap per keyboard, and every phantom "keyboard"
    // (power buttons, hotkey busses, ...) gets its own. Only the one Hyprland
    // marks as main is the one actually being typed on, so lock onto it and
    // ignore layout events from anything else.
    property string device: ""
    property string keymap: ""

    readonly property var shortNames: ({
        "English (US)": "EN",
        "English": "EN",
        "Arabic": "AR",
        "Arabic (Egypt)": "AR",
        "French": "FR",
        "German": "DE",
        "Spanish": "ES",
        "Russian": "RU",
        "Persian": "FA",
        "Turkish": "TR",
        "Hebrew": "HE"
    })

    readonly property string label: {
        if (keymap === "") return "--";
        if (shortNames[keymap] !== undefined) return shortNames[keymap];
        return keymap.substring(0, 2).toUpperCase();
    }

    text: "󰌌 " + label
    color: Colors.text
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 14

    // Hyprland only announces layout *changes*, so the current one has to be
    // read out once at startup.
    Process {
        id: devices
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                const kbs = JSON.parse(text).keyboards;
                if (!kbs || kbs.length === 0) return;
                const kb = kbs.find(k => k.main) || kbs[0];
                root.device = kb.name;
                root.keymap = kb.active_keymap;
            }
        }
    }

    Connections {
        target: Hyprland

        // data is "<keyboard name>,<layout name>"; keyboard names may contain
        // commas, layout names never do.
        function onRawEvent(event) {
            if (event.name === "configreloaded") {
                devices.running = true;
                return;
            }
            if (event.name !== "activelayout") return;

            const comma = event.data.lastIndexOf(",");
            if (comma === -1) return;
            if (event.data.substring(0, comma) !== root.device) return;
            root.keymap = event.data.substring(comma + 1);
        }
    }

    Component.onCompleted: devices.running = true

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        // Switch only this keyboard -- "all" would drag the phantom devices
        // along and move Hyprland's main flag onto one of them.
        onClicked: if (root.device !== "") Quickshell.execDetached(["hyprctl", "switchxkblayout", root.device, "next"])
    }
}
