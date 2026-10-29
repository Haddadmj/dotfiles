import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import qs
import qs.components

// Quick settings (SUPER+A): toggles, volume, Bluetooth / output lists, power buttons.
// Click a tile to toggle it, its arrow to open the list. Esc or click outside closes.
PanelWindow {
    id: root
    readonly property bool open: Ui.quickSettings
    property string expanded: ""    // "", "bt", "audio"

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    WlrLayershell.namespace: "quickshell:quicksettings"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: false

    onOpenChanged: {
        if (open) { hideTimer.stop(); expanded = ""; visible = true; box.forceActiveFocus() }
        else hideTimer.restart()
    }
    Timer { id: hideTimer; interval: Theme.anim; onTriggered: root.visible = false }

    // ── state ────────────────────────────────────────
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property var btDevices: Bluetooth.devices.values.filter(d => d.paired || d.connected)
                                     .sort((a, b) => b.connected - a.connected || a.name.localeCompare(b.name))
    readonly property var btConnected: btDevices.filter(d => d.connected)
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.audio && !n.isStream && n.isSink)
    PwObjectTracker { objects: [root.sink, root.source] }

    property string mode: "dark"
    FileView {
        path: Quickshell.env("HOME") + "/.cache/theme-state"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.mode = text().split("\n")[1] === "light" ? "light" : "dark"
    }

    property string uptime: ""
    Process {
        command: ["cat", "/proc/uptime"]
        running: root.open
        stdout: StdioCollector {
            onStreamFinished: {
                const s = parseFloat(text), d = Math.floor(s / 86400), h = Math.floor(s / 3600) % 24, m = Math.floor(s / 60) % 60
                root.uptime = `up ${d ? d + "d " : ""}${h}h ${m}m`
            }
        }
    }

    function run(cmd) { Ui.quickSettings = false; Quickshell.execDetached(["sh", "-c", cmd]) }

    MouseArea { anchors.fill: parent; onClicked: Ui.quickSettings = false }

    // ── pieces ───────────────────────────────────────
    component Tile: Rectangle {
        id: tile
        property string icon
        property string label
        property string sub: ""
        property bool on: false
        property string list: ""          // which list the arrow opens
        signal toggled()
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 58
        radius: Theme.radius + 2
        color: on ? (tm.containsMouse ? Qt.lighter(Theme.primary, 1.08) : Theme.primary)
                  : (tm.containsMouse ? Theme.alpha(Theme.secondary, 0.9) : Theme.alpha(Theme.secondary, 0.5))
        Behavior on color { ColorAnimation { duration: 150 } }

        MouseArea { id: tm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tile.toggled() }
        KeyFocus { onActivated: tile.toggled() }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 6
            spacing: 12
            T { text: tile.icon; font.pixelSize: 18; color: tile.on ? Theme.primaryText : Theme.fg }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                T { Layout.fillWidth: true; text: tile.label; elide: Text.ElideRight; color: tile.on ? Theme.primaryText : Theme.fg }
                T {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: tile.sub
                    elide: Text.ElideRight
                    font.pixelSize: 11
                    font.weight: Font.Normal
                    color: tile.on ? Theme.alpha(Theme.primaryText, 0.75) : Theme.fgDim
                }
            }
            Rectangle {
                visible: tile.list !== ""
                implicitWidth: 30; implicitHeight: 44; radius: Theme.radius
                color: am.containsMouse ? Theme.alpha(tile.on ? Theme.primaryText : Theme.fg, 0.15) : "transparent"
                T {
                    anchors.centerIn: parent
                    text: root.expanded === tile.list ? Icons.chevronUp : Icons.chevronDown
                    font.pixelSize: 16
                    color: tile.on ? Theme.primaryText : Theme.fg
                }
                MouseArea {
                    id: am
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.expanded = root.expanded === tile.list ? "" : tile.list
                }
                KeyFocus { enabled: tile.list !== ""; onActivated: root.expanded = root.expanded === tile.list ? "" : tile.list }
            }
        }
    }

    component RoundButton: Rectangle {
        id: rb
        property string icon
        property string tip: ""
        property bool danger: false
        signal clicked()
        implicitWidth: 38; implicitHeight: 38; radius: 19
        color: rm.containsMouse ? (danger ? Theme.error : Theme.primary) : Theme.alpha(Theme.secondary, 0.6)
        Behavior on color { ColorAnimation { duration: 150 } }
        T { anchors.centerIn: parent; text: rb.icon; font.pixelSize: 16; color: rm.containsMouse ? (rb.danger ? Theme.errorText : Theme.primaryText) : Theme.fg }
        MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: rb.clicked() }
        KeyFocus { onActivated: rb.clicked() }
    }

    component Divider: Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.islandBorder }

    // ── panel ────────────────────────────────────────
    Rectangle {
        id: box
        anchors.right: parent.right
        anchors.rightMargin: 20
        y: Theme.gap + Theme.barHeight + 6
        width: 400
        height: col.implicitHeight + 28
        radius: Theme.radius + 4
        color: Theme.popup
        border.width: 1
        border.color: Theme.alpha(Theme.primary, 0.35)
        clip: true
        opacity: root.open ? 1 : 0
        transform: Translate { y: root.open ? 0 : -12; Behavior on y { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } } }
        Behavior on opacity { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }

        Keys.onEscapePressed: Ui.quickSettings = false
        Keys.onDownPressed: nextItemInFocusChain(true).forceActiveFocus()
        Keys.onUpPressed: nextItemInFocusChain(false).forceActiveFocus()
        MouseArea { anchors.fill: parent }   // swallow clicks so they don't close

        ColumnLayout {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 14
            y: 14
            spacing: 10

            // header: uptime + power buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                T {
                    Layout.fillWidth: true
                    text: Quickshell.env("USER") + "  ·  " + root.uptime
                    elide: Text.ElideRight
                    color: Theme.fgDim
                    font.weight: Font.Normal
                }
                RoundButton { icon: Icons.settings; onClicked: { Ui.quickSettings = false; Ui.hyprSettings = true } }
                RoundButton { icon: Icons.lock; onClicked: root.run("loginctl lock-session") }
                RoundButton { icon: Icons.suspend; onClicked: root.run("systemctl suspend") }
                RoundButton { icon: Icons.reboot; danger: true; onClicked: root.run("systemctl reboot") }
                RoundButton { icon: Icons.shutdown; danger: true; onClicked: root.run("systemctl poweroff") }
            }

            // toggles
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 8
                columnSpacing: 8

                Tile {
                    icon: !(root.btAdapter?.enabled) ? Icons.btOff : root.btConnected.length ? Icons.btConnected : Icons.bt
                    label: "Bluetooth"
                    sub: !root.btAdapter ? "no adapter" : !root.btAdapter.enabled ? "off"
                       : root.btConnected.length ? root.btConnected.map(d => d.name).join(", ") : "on"
                    on: root.btAdapter?.enabled ?? false
                    list: root.btAdapter ? "bt" : ""
                    onToggled: if (root.btAdapter) root.btAdapter.enabled = !root.btAdapter.enabled
                }
                Tile {
                    icon: Notifs.dnd ? Icons.bellOff : Icons.bell
                    label: "Do not disturb"
                    sub: Notifs.dnd ? "on" : Notifs.count ? `${Notifs.count} notification${Notifs.count > 1 ? "s" : ""}` : "off"
                    on: Notifs.dnd
                    onToggled: Notifs.dnd = !Notifs.dnd
                }
                Tile {
                    icon: root.mode === "dark" ? Icons.moon : Icons.sun
                    label: root.mode === "dark" ? "Dark mode" : "Light mode"
                    sub: "from wallpaper"
                    on: root.mode === "dark"
                    onToggled: Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/theme.sh", "toggle-mode"])
                }
                Tile {
                    icon: Icons.eye
                    label: "Keep awake"
                    sub: Ui.keepAwake ? "screen stays on" : "off"
                    on: Ui.keepAwake
                    onToggled: Ui.keepAwake = !Ui.keepAwake
                }
                Tile {
                    icon: Recorder.recording ? Icons.stop : Icons.record
                    label: Recorder.recording ? "Stop recording" : "Record screen"
                    sub: Recorder.recording ? "recording…" : "focused monitor"
                    Layout.columnSpan: 2
                    on: Recorder.recording
                    onToggled: { Ui.quickSettings = false; Recorder.toggle(false) }
                }
            }

            // ── Bluetooth list ───────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.expanded === "bt"
                spacing: 2
                RowLayout {
                    T { text: "Devices"; color: Theme.primary; Layout.fillWidth: true }
                    T { text: root.btAdapter?.discovering ? "searching…" : ""; color: Theme.fgDim; font.pixelSize: 11 }
                }
                T { visible: root.btDevices.length === 0; text: root.btAdapter?.enabled ? "No paired devices" : "Bluetooth is off"; color: Theme.fgDim }
                Repeater {
                    model: root.btDevices
                    MenuItem {
                        required property var modelData
                        icon: modelData.connected ? Icons.btConnected : Icons.bt
                        text: modelData.name + (modelData.batteryAvailable ? `  ${Math.round(modelData.battery * 100)}%` : "")
                              + (modelData.state === BluetoothDeviceState.Connecting ? "  …" : "")
                        active: modelData.connected
                        implicitHeight: 32
                        onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
                    }
                }
                MenuItem { icon: Icons.settings; text: "Pair new device"; onClicked: root.run("blueman-manager || ghostty -e bluetuith") }
            }

            // ── Output list ──────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.expanded === "audio"
                spacing: 2
                T { text: "Output"; color: Theme.primary }
                Repeater {
                    model: root.sinks
                    MenuItem {
                        required property var modelData
                        icon: modelData === root.sink ? Icons.check : " "
                        text: modelData.description || modelData.nickname || modelData.name
                        active: modelData === root.sink
                        implicitHeight: 32
                        onClicked: Pipewire.preferredDefaultAudioSink = modelData
                    }
                }
            }

            Divider {}

            // volume + mic
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                T {
                    font.pixelSize: 17
                    text: Icons.volumeIcon(root.sink?.audio?.volume ?? 0, root.sink?.audio?.muted ?? false)
                    color: root.sink?.audio?.muted ? Theme.alpha(Theme.fg, 0.45) : Theme.primary
                    MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: if (root.sink?.audio) root.sink.audio.muted = !root.sink.audio.muted }
                    KeyFocus { anchors.margins: -4; onActivated: if (root.sink?.audio) root.sink.audio.muted = !root.sink.audio.muted }
                }
                Slider {
                    Layout.fillWidth: true
                    max: 1.5
                    value: root.sink?.audio?.volume ?? 0
                    accent: root.sink?.audio?.muted ? Theme.alpha(Theme.fg, 0.4) : Theme.primary
                    onMoved: v => { if (root.sink?.audio) root.sink.audio.volume = v }
                }
                T { Layout.preferredWidth: 38; horizontalAlignment: Text.AlignRight; text: `${Math.round((root.sink?.audio?.volume ?? 0) * 100)}%`; color: Theme.fgDim }
                T {
                    text: root.expanded === "audio" ? Icons.chevronUp : Icons.chevronDown
                    font.pixelSize: 16
                    MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: root.expanded = root.expanded === "audio" ? "" : "audio" }
                    KeyFocus { anchors.margins: -4; onActivated: root.expanded = root.expanded === "audio" ? "" : "audio" }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                T {
                    font.pixelSize: 17
                    text: root.source?.audio?.muted ? Icons.micOff : Icons.mic
                    color: root.source?.audio?.muted ? Theme.alpha(Theme.fg, 0.45) : Theme.primary
                    MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: if (root.source?.audio) root.source.audio.muted = !root.source.audio.muted }
                    KeyFocus { anchors.margins: -4; onActivated: if (root.source?.audio) root.source.audio.muted = !root.source.audio.muted }
                }
                Slider {
                    Layout.fillWidth: true
                    value: root.source?.audio?.volume ?? 0
                    accent: root.source?.audio?.muted ? Theme.alpha(Theme.fg, 0.4) : Theme.primary
                    onMoved: v => { if (root.source?.audio) root.source.audio.volume = v }
                }
                T { Layout.preferredWidth: 38; horizontalAlignment: Text.AlignRight; text: root.source?.audio?.muted ? "off" : `${Math.round((root.source?.audio?.volume ?? 0) * 100)}%`; color: Theme.fgDim }
                Item { implicitWidth: 16 }
            }

            // now playing
            Divider { visible: Media.active !== null }
            RowLayout {
                Layout.fillWidth: true
                visible: Media.active !== null
                spacing: 10
                T { text: Icons.music; color: Theme.primary; font.pixelSize: 16 }
                T {
                    Layout.fillWidth: true
                    text: [Media.active?.trackTitle, Media.active?.trackArtist].filter(s => s).join(" · ")
                    elide: Text.ElideRight
                    font.weight: Font.Normal
                }
                Repeater {
                    model: [
                        { icon: Icons.prev, act: () => Media.active.previous() },
                        { icon: Media.active?.isPlaying ? Icons.pause : Icons.play, act: () => Media.active.togglePlaying() },
                        { icon: Icons.next, act: () => Media.active.next() },
                    ]
                    T {
                        required property var modelData
                        text: modelData.icon
                        font.pixelSize: 17
                        MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: parent.modelData.act() }
                        KeyFocus { anchors.margins: -4; onActivated: parent.modelData.act() }
                    }
                }
            }
        }
    }
}
