pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Screen recording with wf-recorder into ~/Videos/Recordings. The bar shows a red dot while it runs.
Singleton {
    id: root
    readonly property bool recording: proc.running
    readonly property string dir: Quickshell.env("HOME") + "/Videos/Recordings"
    property string file: ""
    property date started: new Date()

    // region: true asks for an area with slurp, otherwise the focused monitor
    function start(region) {
        if (recording) return
        file = `${dir}/rec-${Qt.formatDateTime(new Date(), "yyyy-MM-dd_hh-mm-ss")}.mp4`
        started = new Date()
        proc.region = region
        proc.running = true
    }
    function stop() { if (recording) proc.signal(2) }   // SIGINT lets wf-recorder finish the file
    function toggle(region) { recording ? stop() : start(region) }

    Process {
        id: proc
        property bool region: false
        command: ["bash", "-c", `
            command -v wf-recorder >/dev/null || { notify-send -a Recorder "wf-recorder is not installed" "sudo pacman -S wf-recorder"; exit 1; }
            mkdir -p "$1"
            if [ "$2" = 1 ]; then g=$(slurp) || exit 0; set -- "$1" "$2" "$3" -g "$g"
            else set -- "$1" "$2" "$3" -o "$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')"; fi
            trap 'kill -INT $pid; wait $pid' INT
            wf-recorder "\${@:4}" -f "$3" & pid=$!
            wait $pid`, "bash", root.dir, region ? "1" : "0", root.file]
        onExited: Quickshell.execDetached(["sh", "-c",
            `[ -s "$1" ] && notify-send -a Recorder -i video-x-generic "Recording saved" "$1" || true`, "sh", root.file])
    }
}
