import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs
import qs.components

// Shows up only while something is listening or watching: an app using the mic,
// the screen / camera being shared, or our own screen recording (click to stop it).
Island {
    id: root
    readonly property var nodes: Pipewire.nodes.values
    readonly property var micApps: nodes.filter(n => n.type === PwNodeType.AudioInStream)
    readonly property var video: nodes.filter(n => n.type === PwNodeType.VideoSource)
    readonly property bool mic: micApps.length > 0
    readonly property bool screen: video.length > 0
    visible: mic || screen || Recorder.recording
    padding: 10
    spacing: 8
    color: Theme.alpha(Theme.error, hovered ? 0.35 : 0.2)
    border.color: Theme.alpha(Theme.error, 0.6)

    function appName(n) {
        const p = n.properties ?? {}
        return p["application.name"] || n.description || n.nickname || n.name
    }

    clickable: Recorder.recording
    onClicked: Recorder.stop()

    // recording: blinking dot + elapsed time
    RowLayout {
        visible: Recorder.recording
        spacing: 6
        Rectangle {
            implicitWidth: 9; implicitHeight: 9; radius: 5
            color: Theme.error
            SequentialAnimation on opacity {
                running: Recorder.recording
                loops: Animation.Infinite
                NumberAnimation { to: 0.25; duration: 700 }
                NumberAnimation { to: 1; duration: 700 }
            }
        }
        T {
            SystemClock { id: clock; precision: SystemClock.Seconds; enabled: Recorder.recording }
            text: Media.time((clock.date - Recorder.started) / 1000)
            color: Theme.error
        }
    }
    T { visible: root.mic; text: Icons.mic; color: Theme.error; font.pixelSize: 15 }
    T { visible: root.screen; text: Icons.monitor; color: Theme.error; font.pixelSize: 15 }

    Tip {
        target: root
        show: root.hovered
        text: [
            Recorder.recording ? `Recording screen<br><font color='${Theme.fgDim}'>click: stop</font>` : "",
            root.mic ? "Microphone: " + [...new Set(root.micApps.map(root.appName))].join(", ") : "",
            root.screen ? "Screen / camera: " + [...new Set(root.video.map(root.appName))].join(", ") : "",
        ].filter(s => s).join("<br>")
    }
}
