import QtQuick
import Quickshell
import Quickshell.Io

// Pending-update counter. Clicking it refreshes the mirrorlist and runs a
// full repo + AUR upgrade in a terminal.
Text {
    id: root

    property int repoCount: 0
    property int aurCount: 0
    property bool checking: false
    property bool updating: false

    // Repo backlog worth nagging about. AUR is left out on purpose: those
    // packages pile up harmlessly, so a big AUR number is not a warning sign.
    property int repoAlertThreshold: 30

    readonly property int count: repoCount < 0 || aurCount < 0
        ? -1 : repoCount + aurCount

    readonly property string scripts: Quickshell.shellPath("scripts")

    text: {
        if (updating) return "\uf021  updating";
        if (count < 0) return "\uf0ed  ?";
        if (count === 0) return "\uf0ed  0";
        // Labelled so it's obvious at a glance which half is the backlog.
        return "\uf0ed  Arch:" + repoCount + ", AUR:" + aurCount;
    }

    color: {
        if (updating) return Colors.accent;
        if (repoCount >= repoAlertThreshold) return Colors.error;
        if (count > 0) return Colors.warning;
        return Colors.text;
    }
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
                // The script prints "Arch:2, AUR:0" so it reads on its own in a
                // terminal; pull the two numbers back out of that.
                const m = text.match(/Arch:(\d+),\s*AUR:(\d+)/);
                root.repoCount = m ? parseInt(m[1], 10) : -1;
                root.aurCount = m ? parseInt(m[2], 10) : -1;
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
