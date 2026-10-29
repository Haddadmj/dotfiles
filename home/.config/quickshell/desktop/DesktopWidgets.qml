import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.components

// Widgets on the wallpaper, under all windows: a big clock and a now-playing card.
// Only the media card takes clicks; the rest of the desktop is click-through.
PanelWindow {
    id: root
    required property var modelData
    screen: modelData

    WlrLayershell.namespace: "quickshell:desktop"
    WlrLayershell.layer: WlrLayer.Bottom
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    mask: Region { item: media.visible ? media : null }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // clock: soft shadow so it reads on any wallpaper
    ColumnLayout {
        anchors.left: parent.left
        anchors.leftMargin: 70
        y: Theme.gap + Theme.barHeight + 60
        spacing: -6

        Text {
            text: Qt.formatTime(clock.date, "hh:mm")
            font.family: Theme.font
            font.pixelSize: 110
            font.weight: Font.Bold
            color: Theme.alpha(Theme.fg, 0.9)
            style: Text.Raised
            styleColor: Theme.alpha(Theme.bg, 0.5)
        }
        Text {
            Layout.leftMargin: 6
            text: Qt.formatDate(clock.date, "dddd, d MMMM")
            font.family: Theme.font
            font.pixelSize: 24
            color: Theme.alpha(Theme.primary, 0.95)
            style: Text.Raised
            styleColor: Theme.alpha(Theme.bg, 0.5)
        }
    }

    // now playing
    Rectangle {
        id: media
        readonly property var p: Media.active
        visible: p !== null && (p?.trackTitle ?? "") !== ""
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 50
        width: 420
        height: 132
        radius: Theme.radius + 6
        color: Theme.alpha(Theme.bg, 0.72)
        border.width: 1
        border.color: Theme.alpha(Theme.primary, 0.3)

        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 14

            ClippingRectangle {
                implicitWidth: 104
                implicitHeight: 104
                radius: Theme.radius
                color: Theme.alpha(Theme.secondary, 0.8)
                Image {
                    anchors.fill: parent
                    source: media.p?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(208, 208)
                    asynchronous: true
                }
                T {
                    anchors.centerIn: parent
                    visible: !(media.p?.trackArtUrl)
                    text: Icons.music
                    font.pixelSize: 36
                    color: Theme.primary
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                T {
                    Layout.fillWidth: true
                    text: media.p?.trackTitle ?? ""
                    font.pixelSize: 15
                    elide: Text.ElideRight
                }
                T {
                    Layout.fillWidth: true
                    text: media.p?.trackArtist ?? ""
                    color: Theme.fgDim
                    font.weight: Font.Normal
                    elide: Text.ElideRight
                }

                // progress
                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    implicitHeight: 4
                    radius: 2
                    color: Theme.alpha(Theme.fg, 0.15)
                    visible: (media.p?.length ?? 0) > 0
                    Rectangle {
                        height: parent.height
                        radius: 2
                        width: parent.width * Math.min(1, (media.p?.position ?? 0) / Math.max(1, media.p?.length ?? 1))
                        color: Theme.primary
                    }
                }

                RowLayout {
                    Layout.topMargin: 4
                    spacing: 18
                    Repeater {
                        model: [
                            { icon: Icons.prev, act: () => media.p.previous() },
                            { icon: media.p?.isPlaying ? Icons.pause : Icons.play, act: () => media.p.togglePlaying() },
                            { icon: Icons.next, act: () => media.p.next() },
                        ]
                        T {
                            required property var modelData
                            text: modelData.icon
                            font.pixelSize: 22
                            color: bm.containsMouse ? Theme.primary : Theme.fg
                            MouseArea { id: bm; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.modelData.act() }
                        }
                    }
                    Item { Layout.fillWidth: true }
                    T {
                        text: (media.p?.length ?? 0) > 0 ? `${Media.time(media.p.position)} / ${Media.time(media.p.length)}` : ""
                        color: Theme.fgDim
                        font.pixelSize: 11
                        font.weight: Font.Normal
                    }
                }
            }
        }
    }
}
