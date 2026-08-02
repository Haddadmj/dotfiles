pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Shared game-mode state for the bar indicator.
//
// The state itself lives in ~/.local/bin/game-mode, not here -- that script is
// driven from three directions (SUPER + ALT + G, the bar indicator, and
// gamemoded's start/end hooks when a Steam title launches), so the shell must
// not keep its own idea of what is on. Everything routes through the script and
// the script pushes a refresh back with `qs ipc call gamemode sync`.
Singleton {
    id: root

    property bool active: false

    readonly property string script: Quickshell.env("HOME") + "/.local/bin/game-mode"

    // `game-mode status` prints on/off and exits 1 when off; only stdout is read
    // so the exit code does not matter here.
    Process {
        id: probe
        command: [root.script, "status"]

        stdout: StdioCollector {
            onStreamFinished: root.active = text.trim() === "on"
        }
    }

    function sync(): void {
        probe.running = true;
    }

    function toggle(): void {
        // The script calls back into `sync` when it is done, so there is
        // nothing to update optimistically here.
        Quickshell.execDetached([root.script, "toggle"]);
    }

    // Picks up a game already running if the shell is restarted mid-session.
    Component.onCompleted: root.sync()
}
