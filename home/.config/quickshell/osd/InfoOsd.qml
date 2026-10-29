import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.components

// Small pill at the bottom of the screen for keyboard layout switches and track changes
// (same spot as the volume OSD). Track toasts are skipped in do-not-disturb.
PanelWindow {
    id: root
    property bool shown: false
    property string icon: ""
    property string title: ""
    property string sub: ""
    property string art: ""

    WlrLayershell.namespace: "quickshell:osd"
    WlrLayershell.layer: WlrLayer.Overlay
    anchors.bottom: true
    margins.bottom: 160
    exclusiveZone: 0
    implicitWidth: Math.max(260, Math.min(520, row.implicitWidth + 44))
    implicitHeight: art ? 72 : 54
    color: "transparent"
    visible: shown || fade.running
    mask: Region {}   // clicks pass through

    function show(icon, title, sub, art) {
        root.icon = icon; root.title = title; root.sub = sub ?? ""; root.art = art ?? ""
        shown = true
        hideTimer.restart()
    }
    Timer { id: hideTimer; interval: 1800; onTriggered: root.shown = false }

    // ignore the burst of events at startup / reload
    property bool ready: false
    Timer { running: true; interval: 2000; onTriggered: root.ready = true }

    // keyboard layout
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (!root.ready || event.name !== "activelayout") return
            const layout = event.data.slice(event.data.indexOf(",") + 1)
            root.show(Icons.keyboard, layout)
        }
    }

    // track change
    property string lastTrack: ""
    readonly property string track: [Media.active?.trackTitle ?? "", Media.active?.trackArtist ?? ""].join("\n")
    onTrackChanged: {
        const t = Media.active?.trackTitle ?? ""
        if (root.ready && t && track !== lastTrack && Media.active?.isPlaying && !Notifs.dnd)
            root.show(Icons.music, t, Media.active?.trackArtist ?? "", Media.active?.trackArtUrl ?? "")
        lastTrack = track
    }

    Rectangle {
        anchors.fill: parent
        radius: root.art ? Theme.radius + 6 : height / 2
        color: Theme.popup
        border.width: 1
        border.color: Theme.alpha(Theme.primary, 0.35)
        opacity: root.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { id: fade; duration: Theme.anim } }

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 14

            ClippingRectangle {
                visible: root.art !== ""
                implicitWidth: 52; implicitHeight: 52
                radius: Theme.radius - 2
                color: "transparent"
                Image { anchors.fill: parent; source: root.art; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(104, 104); asynchronous: true }
            }
            T { visible: root.art === ""; text: root.icon; font.pixelSize: 20; color: Theme.primary }
            ColumnLayout {
                spacing: 0
                T { text: root.title; Layout.maximumWidth: 400; elide: Text.ElideRight }
                T { visible: root.sub !== ""; text: root.sub; color: Theme.fgDim; font.weight: Font.Normal; Layout.maximumWidth: 400; elide: Text.ElideRight }
            }
        }
    }
}
