import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs
import qs.components

// Volume + mic. Click: mixer popup (devices + per-app volume) · right: mute · middle: mute mic · scroll: ±5% (max 150%)
Island {
    id: root
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property bool micMuted: source?.audio?.muted ?? false

    readonly property string sinkIcon: {
        const p = sink?.properties ?? {}
        const kind = `${p["device.form-factor"] ?? ""} ${p["device.icon-name"] ?? ""} ${sink?.name ?? ""}`
        const bt = kind.includes("bluez") ? Icons.bt : ""
        if (kind.includes("headset")) return Icons.headset + bt
        if (kind.includes("headphone")) return Icons.headphone + bt
        return Icons.volumeIcon(volume, false) + bt
    }

    // apps playing audio (tracked so their volume / name are live)
    readonly property var streams: Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioOutStream)

    PwObjectTracker { objects: [root.sink, root.source, ...root.streams] }

    clickable: true
    onClicked: e => {
        if (e.button === Qt.RightButton) { if (sink?.audio) sink.audio.muted = !sink.audio.muted }
        else if (e.button === Qt.MiddleButton) { if (source?.audio) source.audio.muted = !source.audio.muted }
        else Ui.toggle("audio")
    }
    onScrolled: delta => {
        if (!sink?.audio) return
        sink.audio.volume = Math.max(0, Math.min(1.5, Math.round((volume + (delta > 0 ? 0.05 : -0.05)) * 20) / 20))
    }

    T {
        text: root.muted ? `${Icons.muted} muted` : `${root.sinkIcon} ${Math.round(root.volume * 100)}%`
        color: root.muted ? Theme.alpha(Theme.fg, 0.45) : Theme.fg
    }
    T {
        Layout.leftMargin: 10
        text: root.micMuted ? Icons.micOff : Icons.mic
        color: root.micMuted ? Theme.alpha(Theme.fg, 0.45) : Theme.fg
    }

    Tip {
        target: root
        show: root.hovered
        text: `${root.sink?.description ?? "No output"}<br><font color='${Theme.fgDim}'>left: mixer · right: mute · middle: mic</font>`
    }

    BarPopup {
        id: popup
        target: root
        name: "audio"
        align: 0.5
        padding: 14

        component Section: ColumnLayout {
            id: sec
            required property string title
            required property var node
            required property var nodes
            required property bool output
            spacing: 6
            Layout.preferredWidth: 320

            RowLayout {
                T { text: sec.title; color: Theme.primary; Layout.fillWidth: true }
                T { text: `${Math.round((sec.node?.audio?.volume ?? 0) * 100)}%`; color: Theme.fgDim }
            }
            RowLayout {
                spacing: 10
                T {
                    font.pixelSize: 16
                    text: sec.output ? Icons.volumeIcon(sec.node?.audio?.volume ?? 0, sec.node?.audio?.muted ?? false)
                                     : (sec.node?.audio?.muted ? Icons.micOff : Icons.mic)
                    color: sec.node?.audio?.muted ? Theme.alpha(Theme.fg, 0.45) : Theme.fg
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (sec.node?.audio) sec.node.audio.muted = !sec.node.audio.muted
                    }
                    KeyFocus { onActivated: if (sec.node?.audio) sec.node.audio.muted = !sec.node.audio.muted }
                }
                Slider {
                    Layout.fillWidth: true
                    max: sec.output ? 1.5 : 1
                    value: sec.node?.audio?.volume ?? 0
                    accent: sec.node?.audio?.muted ? Theme.alpha(Theme.fg, 0.4) : Theme.primary
                    onMoved: v => { if (sec.node?.audio) sec.node.audio.volume = v }
                }
            }
            Repeater {
                model: sec.nodes
                MenuItem {
                    required property var modelData
                    text: modelData.description || modelData.nickname || modelData.name
                    icon: modelData === sec.node ? Icons.check : " "
                    active: modelData === sec.node
                    implicitHeight: 30
                    onClicked: {
                        if (sec.output) Pipewire.preferredDefaultAudioSink = modelData
                        else Pipewire.preferredDefaultAudioSource = modelData
                    }
                }
            }
        }

        readonly property var devices: Pipewire.nodes.values.filter(n => n.audio && !n.isStream)

        Section {
            title: "Output"
            node: root.sink
            nodes: popup.devices.filter(n => n.isSink)
            output: true
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.islandBorder; Layout.topMargin: 4; Layout.bottomMargin: 4 }
        // per-app volume
        ColumnLayout {
            visible: root.streams.length > 0
            Layout.preferredWidth: 320
            spacing: 6
            T { text: "Apps"; color: Theme.primary }
            Repeater {
                model: root.streams
                ColumnLayout {
                    id: app
                    required property var modelData
                    readonly property var props: modelData.properties ?? {}
                    readonly property bool muted: modelData.audio?.muted ?? false
                    Layout.fillWidth: true
                    spacing: 2
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        T {
                            text: app.props["application.name"] || app.modelData.description || app.modelData.name
                            elide: Text.ElideRight
                            Layout.maximumWidth: 150
                        }
                        T {
                            Layout.fillWidth: true
                            text: app.props["media.name"] ?? ""
                            elide: Text.ElideRight
                            color: Theme.fgDim
                            font.pixelSize: 11
                            font.weight: Font.Normal
                        }
                        T { text: `${Math.round((app.modelData.audio?.volume ?? 0) * 100)}%`; color: Theme.fgDim }
                    }
                    RowLayout {
                        spacing: 10
                        T {
                            font.pixelSize: 16
                            text: Icons.volumeIcon(app.modelData.audio?.volume ?? 0, app.muted)
                            color: app.muted ? Theme.alpha(Theme.fg, 0.45) : Theme.fg
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (app.modelData.audio) app.modelData.audio.muted = !app.muted
                            }
                            KeyFocus { onActivated: if (app.modelData.audio) app.modelData.audio.muted = !app.muted }
                        }
                        Slider {
                            Layout.fillWidth: true
                            value: app.modelData.audio?.volume ?? 0
                            accent: app.muted ? Theme.alpha(Theme.fg, 0.4) : Theme.primary
                            onMoved: v => { if (app.modelData.audio) app.modelData.audio.volume = v }
                        }
                    }
                }
            }
        }
        Rectangle { visible: root.streams.length > 0; Layout.fillWidth: true; implicitHeight: 1; color: Theme.islandBorder; Layout.topMargin: 4; Layout.bottomMargin: 4 }
        Section {
            title: "Input"
            node: root.source
            nodes: popup.devices.filter(n => !n.isSink)
            output: false
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.islandBorder; Layout.topMargin: 4; Layout.bottomMargin: 2 }
        MenuItem {
            icon: Icons.mixer
            text: "Open mixer"
            onClicked: { Ui.popup = ""; Quickshell.execDetached(["pavucontrol"]) }
        }
    }
}
