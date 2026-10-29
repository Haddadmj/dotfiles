import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import qs
import qs.components

// Volume / mute indicator at the bottom of the screen when the volume changes (keys, scroll, apps).
PanelWindow {
    id: root
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    property bool shown: false
    property bool mic: false   // last change was the mic mute

    WlrLayershell.namespace: "quickshell:osd"
    WlrLayershell.layer: WlrLayer.Overlay
    anchors.bottom: true
    margins.bottom: 90
    exclusiveZone: 0
    implicitWidth: 300
    implicitHeight: 54
    color: "transparent"
    visible: shown || fade.running
    mask: Region {}   // clicks pass through

    PwObjectTracker { objects: [root.sink, root.source] }

    // ignore the burst of change signals while devices appear
    property bool ready: false
    Timer { running: true; interval: 1500; onTriggered: root.ready = true }
    onSinkChanged: { ready = false; settle.restart() }
    Timer { id: settle; interval: 800; onTriggered: root.ready = true }

    function flash(isMic) {
        if (!ready) return
        mic = isMic
        shown = true
        hideTimer.restart()
    }
    Timer { id: hideTimer; interval: 1400; onTriggered: root.shown = false }

    Connections {
        target: root.sink?.audio ?? null
        function onVolumeChanged() { root.flash(false) }
        function onMutedChanged() { root.flash(false) }
    }
    Connections {
        target: root.source?.audio ?? null
        function onMutedChanged() { root.flash(true) }
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.popup
        border.width: 1
        border.color: Theme.alpha(Theme.primary, 0.35)
        opacity: root.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { id: fade; duration: Theme.anim } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            spacing: 14

            readonly property var audio: root.mic ? root.source?.audio : root.sink?.audio

            T {
                font.pixelSize: 20
                text: root.mic ? (parent.audio?.muted ? Icons.micOff : Icons.mic)
                               : Icons.volumeIcon(parent.audio?.volume ?? 0, parent.audio?.muted ?? false)
                color: parent.audio?.muted ? Theme.alpha(Theme.fg, 0.5) : Theme.primary
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 6
                radius: 3
                color: Theme.alpha(Theme.fg, 0.15)
                Rectangle {
                    height: parent.height
                    radius: 3
                    width: parent.width * Math.min(1, parent.parent.audio?.volume ?? 0)
                    color: parent.parent.audio?.muted ? Theme.alpha(Theme.fg, 0.4) : Theme.primary
                    Behavior on width { NumberAnimation { duration: 120 } }
                }
            }
            T {
                Layout.preferredWidth: 44
                horizontalAlignment: Text.AlignRight
                text: parent.audio?.muted ? "muted" : `${Math.round((parent.audio?.volume ?? 0) * 100)}%`
                color: Theme.fg
            }
        }
    }
}
