import QtQuick
import Quickshell
import Quickshell.Io

// Pending-update counter. Clicking it refreshes the mirrorlist and runs a
// full repo + AUR upgrade in a terminal.
Text {
    id: root

    property int count: 0
    property bool checking: false
    property bool updating: false

    readonly property string scripts: Quickshell.shellPath("scripts")

    text: {
        if (updating) return "\uf021  updating";
        if (count < 0) return "\uf0ed  ?";
        return "\uf0ed  " + count;
    }

    color: updating ? Colors.accent
        : (count > 0 ? Colors.warning : Colors.text)
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 14

    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    Process {
        id: check
        command: ["sh", root.scripts + "/check-updates.sh"]
        onRunningChanged: root.checking = running

        stdout: StdioCollector {
            onStreamFinished: {
                const n = parseInt(text.trim(), 10);
                root.count = isNaN(n) ? -1 : n;
            }
        }
    }

    // The terminal owns the upgrade; when it exits we re-check the count.
    Process {
        id: update
        command: [
            "alacritty",
            "--class", "hypr-update",
            "-e", "sh", "-c",
            root.scripts + "/system-update.sh || read -p 'Update failed — press Enter to close '"
        ]

        onRunningChanged: {
            root.updating = running;
            if (!running) check.running = true;
        }
    }

    Timer {
        interval: 30 * 60 * 1000 // every 30 minutes
        running: true
        repeat: true
        onTriggered: if (!root.updating) check.running = true
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (root.updating) return;

            // Right click just re-checks without starting an upgrade.
            if (mouse.button === Qt.RightButton) check.running = true;
            else update.running = true;
        }
    }

    Component.onCompleted: check.running = true
}
