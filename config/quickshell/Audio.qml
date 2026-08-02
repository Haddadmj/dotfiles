import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    PwObjectTracker {
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property real vol: sink && sink.audio ? sink.audio.volume : 0

    Row {
        id: row
        spacing: 6

        Text {
            text: root.muted ? "" : (root.vol > 0.5 ? "" : root.vol > 0 ? "" : "")
            color: root.muted ? Colors.error : Colors.text
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
        }

        Text {
            text: Math.round(root.vol * 100) + "%"
            color: root.muted ? Colors.error : Colors.text
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (!root.sink || !root.sink.audio) return;
            if (mouse.button === Qt.LeftButton) {
                root.sink.audio.muted = !root.sink.audio.muted;
            } else {
                Quickshell.execDetached(["pavucontrol"]);
            }
        }
        onWheel: wheel => {
            if (!root.sink || !root.sink.audio) return;
            const step = 0.05;
            const delta = (wheel.angleDelta.y / 120) * step;
            root.sink.audio.volume = Math.max(0, Math.min(1, root.sink.audio.volume + delta));
        }
    }
}
