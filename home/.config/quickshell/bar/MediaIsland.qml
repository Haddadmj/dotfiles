import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs
import qs.components

// Now playing. Click: player popup · middle: play/pause · right: next track. Hidden when nothing is open.
Island {
    id: root
    readonly property var player: Media.active
    readonly property string label: player ? [player.trackTitle, player.trackArtist].filter(s => s).join("  ·  ") || player.identity : ""

    visible: opacity > 0
    opacity: player ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.anim } }
    spacing: 8

    clickable: true
    onClicked: e => {
        if (!player) return
        if (e.button === Qt.MiddleButton) player.togglePlaying()
        else if (e.button === Qt.RightButton) { if (player.canGoNext) player.next() }
        else Ui.toggle("media")
    }

    T {
        text: root.player?.isPlaying ? Icons.music : Icons.pause
        color: Theme.primary
        font.pixelSize: 15
    }
    T {
        text: root.label
        elide: Text.ElideRight
        Layout.maximumWidth: 260
        color: root.player?.isPlaying ? Theme.fg : Theme.fgDim
    }

    BarPopup {
        id: popup
        target: root
        name: "media"
        align: 0
        padding: 14
        readonly property var p: root.player

        RowLayout {
            spacing: 14
            Layout.preferredWidth: 380

            ClippingRectangle {
                implicitWidth: 96
                implicitHeight: 96
                radius: Theme.radius
                color: Theme.alpha(Theme.secondary, 0.8)
                Image {
                    id: art
                    anchors.fill: parent
                    source: popup.p?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(192, 192)
                    asynchronous: true
                }
                T {
                    anchors.centerIn: parent
                    visible: art.status !== Image.Ready
                    text: Icons.music
                    font.pixelSize: 36
                    color: Theme.primary
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                T { Layout.fillWidth: true; text: popup.p?.trackTitle || "Unknown title"; font.pixelSize: 15; elide: Text.ElideRight; maximumLineCount: 1 }
                T { Layout.fillWidth: true; text: popup.p?.trackArtist ?? ""; color: Theme.primary; elide: Text.ElideRight; visible: text !== "" }
                T { Layout.fillWidth: true; text: popup.p?.trackAlbum ?? ""; color: Theme.fgDim; font.weight: Font.Normal; font.pixelSize: 12; elide: Text.ElideRight; visible: text !== "" }
                Item { Layout.fillHeight: true }
                T { text: popup.p?.identity ?? ""; color: Theme.alpha(Theme.fg, 0.45); font.pixelSize: 11; font.weight: Font.Normal }
            }
        }

        // progress
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 6
            spacing: 2
            visible: (popup.p?.lengthSupported ?? false) && popup.p.length > 0
            Slider {
                Layout.fillWidth: true
                max: popup.p?.length ?? 1
                value: popup.p?.position ?? 0
                enabled: popup.p?.canSeek ?? false
                onMoved: v => { if (popup.p?.canSeek) popup.p.position = v }
            }
            RowLayout {
                Layout.fillWidth: true
                T { text: Media.time(popup.p?.position ?? 0); color: Theme.fgDim; font.pixelSize: 11; Layout.fillWidth: true }
                T { text: Media.time(popup.p?.length ?? 0); color: Theme.fgDim; font.pixelSize: 11 }
            }
        }

        // controls
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 14

            component Ctl: Rectangle {
                id: ctl
                property string icon
                property bool big: false
                property bool on: false
                property bool usable: true
                signal clicked()
                implicitWidth: big ? 48 : 36
                implicitHeight: implicitWidth
                radius: implicitWidth / 2
                opacity: usable ? 1 : 0.35
                color: big ? (m.containsMouse ? Theme.alpha(Theme.primary, 0.85) : Theme.primary)
                           : m.containsMouse ? Theme.alpha(Theme.secondary, 0.9) : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }
                T {
                    anchors.centerIn: parent
                    text: ctl.icon
                    font.pixelSize: ctl.big ? 22 : 17
                    color: ctl.big ? Theme.primaryText : ctl.on ? Theme.primary : Theme.fg
                }
                MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; enabled: ctl.usable; cursorShape: Qt.PointingHandCursor; onClicked: ctl.clicked() }
            }

            Ctl {
                icon: Icons.shuffle
                visible: popup.p?.shuffleSupported ?? false
                on: popup.p?.shuffle ?? false
                onClicked: popup.p.shuffle = !popup.p.shuffle
            }
            Ctl { icon: Icons.prev; usable: popup.p?.canGoPrevious ?? false; onClicked: popup.p.previous() }
            Ctl { icon: popup.p?.isPlaying ? Icons.pause : Icons.play; big: true; usable: popup.p?.canTogglePlaying ?? false; onClicked: popup.p.togglePlaying() }
            Ctl { icon: Icons.next; usable: popup.p?.canGoNext ?? false; onClicked: popup.p.next() }
            Ctl {
                icon: popup.p?.loopState === MprisLoopState.Track ? Icons.repeatOnce : Icons.repeat
                visible: popup.p?.loopSupported ?? false
                on: (popup.p?.loopState ?? MprisLoopState.None) !== MprisLoopState.None
                onClicked: popup.p.loopState = popup.p.loopState === MprisLoopState.None ? MprisLoopState.Playlist
                                             : popup.p.loopState === MprisLoopState.Playlist ? MprisLoopState.Track
                                             : MprisLoopState.None
            }
        }

        // other players
        ColumnLayout {
            Layout.fillWidth: true
            visible: Media.players.length > 1
            spacing: 2
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.islandBorder; Layout.topMargin: 4; Layout.bottomMargin: 4 }
            Repeater {
                model: Media.players
                MenuItem {
                    required property var modelData
                    implicitHeight: 30
                    icon: modelData === popup.p ? Icons.check : " "
                    active: modelData === popup.p
                    text: `${modelData.identity}${modelData.trackTitle ? "  ·  " + modelData.trackTitle : ""}`
                    onClicked: Media.chosen = modelData
                }
            }
        }
    }
}
