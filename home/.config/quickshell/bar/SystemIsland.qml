import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking
import qs
import qs.components

// network · bluetooth · notifications
Island {
    id: root
    padding: 6

    // ── Network ──────────────────────────────────────
    MouseArea {
        id: net
        Layout.preferredWidth: netIcon.implicitWidth + 14
        Layout.fillHeight: true
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["nm-connection-editor"])
        KeyFocus { id: netKey; onActivated: Quickshell.execDetached(["nm-connection-editor"]) }

        readonly property var devices: Networking.devices.values
        readonly property var device: devices.find(d => d.connected && d.type === DeviceType.Wifi)
                                   ?? devices.find(d => d.connected) ?? null
        readonly property bool wifi: device?.type === DeviceType.Wifi
        readonly property var network: wifi ? device.networks.values.find(n => n.connected) ?? null : null
        readonly property real strength: {
            const s = network?.signalStrength ?? 0
            return s > 1 ? s / 100 : s
        }

        T {
            id: netIcon
            anchors.centerIn: parent
            font.pixelSize: 15
            text: !net.device ? Icons.offline
                : net.wifi ? Icons.wifi[Math.min(4, Math.floor(net.strength * 5))]
                : Icons.ethernet
            color: net.device ? Theme.fg : Theme.alpha(Theme.fg, 0.4)
        }

        // IP + throughput, only polled while the tooltip is up
        property string ip: ""
        property real rx: -1
        property real tx: -1
        property real rxRate: 0
        property real txRate: 0
        function human(b) {
            const u = ["B", "KB", "MB", "GB"]
            let i = 0
            while (b >= 1024 && i < u.length - 1) { b /= 1024; i++ }
            return `${b.toFixed(i ? 1 : 0)} ${u[i]}/s`
        }

        Process {
            id: ipProc
            command: ["sh", "-c", `ip -4 -o addr show dev ${net.device?.name ?? "lo"} | awk '{print $4}'`]
            stdout: StdioCollector { onStreamFinished: net.ip = text.trim() }
        }
        Process {
            id: statsProc
            command: ["sh", "-c", `cat /sys/class/net/${net.device?.name ?? "lo"}/statistics/{rx,tx}_bytes`]
            stdout: StdioCollector {
                onStreamFinished: {
                    const [r, t] = text.trim().split("\n").map(Number)
                    if (net.rx >= 0) { net.rxRate = r - net.rx; net.txRate = t - net.tx }
                    net.rx = r; net.tx = t
                }
            }
        }
        Timer {
            running: net.containsMouse && net.device !== null
            interval: 1000
            repeat: true
            triggeredOnStart: true
            onTriggered: statsProc.running = true
        }
        onContainsMouseChanged: if (containsMouse) { rx = -1; rxRate = 0; txRate = 0; ipProc.running = true }

        Tip {
            target: net
            show: net.containsMouse || netKey.activeFocus
            text: !net.device ? "Offline"
                : (net.wifi ? `<b>${net.network?.name ?? ""}</b>  ${Math.round(net.strength * 100)}%` : `<b>${net.device.name}</b>`)
                  + `<br>${net.ip}<br>${Icons.down} ${net.human(net.rxRate)}   ${Icons.up} ${net.human(net.txRate)}`
        }
    }

    // ── Bluetooth ────────────────────────────────────
    MouseArea {
        id: bt
        Layout.preferredWidth: btIcon.implicitWidth + 14
        Layout.fillHeight: true
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        readonly property var adapter: Bluetooth.defaultAdapter
        readonly property bool on: adapter?.enabled ?? false
        readonly property var connected: Bluetooth.devices.values.filter(d => d.connected)
        readonly property var battery: connected.find(d => d.batteryAvailable)

        onClicked: e => {
            if (e.button === Qt.RightButton) Quickshell.execDetached(["sh", "-c", "blueman-manager || blueberry || ghostty -e bluetuith"])
            else if (adapter) adapter.enabled = !adapter.enabled
        }
        KeyFocus { id: btKey; onActivated: if (bt.adapter) bt.adapter.enabled = !bt.adapter.enabled }

        T {
            id: btIcon
            anchors.centerIn: parent
            font.pixelSize: 15
            text: !bt.on ? Icons.btOff
                : bt.connected.length === 0 ? Icons.bt
                : Icons.btConnected + (bt.battery ? ` ${Math.round(bt.battery.battery * 100)}%` : "")
            color: !bt.on ? Theme.alpha(Theme.fg, 0.4) : bt.connected.length ? Theme.primary : Theme.fg
        }

        Tip {
            target: bt
            show: bt.containsMouse || btKey.activeFocus
            text: !bt.adapter ? "No Bluetooth adapter"
                : !bt.on ? "Bluetooth off<br><font color='" + Theme.fgDim + "'>click: turn on</font>"
                : bt.connected.length === 0 ? "Bluetooth on<br><font color='" + Theme.fgDim + "'>click: turn off · right: devices</font>"
                : bt.connected.map(d => d.name + (d.batteryAvailable ? `  ${Math.round(d.battery * 100)}%` : "")).join("<br>")
        }
    }

    // ── Tailscale ────────────────────────────────────
    MouseArea {
        id: ts
        Layout.preferredWidth: tsIcon.implicitWidth + 14
        Layout.fillHeight: true
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        // BackendState: Running · Stopped · NeedsLogin · NoState (daemon down)
        property string state: ""
        property string ip: ""
        property var peers: []
        readonly property bool on: state === "Running"

        // works without sudo because the user is the tailscale operator (tailscale up --operator)
        onClicked: if (!toggleProc.running) toggleProc.running = true
        KeyFocus { id: tsKey; onActivated: if (!toggleProc.running) toggleProc.running = true }
        Process {
            id: toggleProc
            command: ["tailscale", ts.on ? "down" : "up"]
            onExited: statusProc.running = true
        }

        Process {
            id: statusProc
            command: ["tailscale", "status", "--json"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const d = JSON.parse(text)
                        ts.state = d.BackendState
                        ts.ip = d.Self?.TailscaleIPs?.[0] ?? ""
                        ts.peers = Object.values(d.Peer ?? {}).filter(p => p.Online).map(p => p.HostName)
                    } catch (e) { ts.state = "" }
                }
            }
        }
        Timer {
            running: true
            interval: 5000
            repeat: true
            triggeredOnStart: true
            onTriggered: statusProc.running = true
        }

        T {
            id: tsIcon
            anchors.centerIn: parent
            font.pixelSize: 15
            text: Icons.vpn
            color: ts.on ? Theme.primary : Theme.alpha(Theme.fg, 0.4)
        }

        Tip {
            target: ts
            show: ts.containsMouse || tsKey.activeFocus
            text: !ts.state ? "Tailscale daemon not running"
                : ts.state === "NeedsLogin" ? "Tailscale: logged out<br><font color='" + Theme.fgDim + "'>run: tailscale up</font>"
                : !ts.on ? "Tailscale off<br><font color='" + Theme.fgDim + "'>click: connect</font>"
                : `<b>Tailscale</b>  ${ts.ip}<br>` + (ts.peers.length ? ts.peers.join("<br>") : "no peers online")
                  + "<br><font color='" + Theme.fgDim + "'>click: disconnect</font>"
        }
    }

    // ── Notifications ────────────────────────────────
    MouseArea {
        id: bell
        Layout.preferredWidth: bellIcon.implicitWidth + 14
        Layout.fillHeight: true
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: e => {
            if (e.button === Qt.RightButton) Notifs.dnd = !Notifs.dnd
            else Ui.notifCenter = !Ui.notifCenter
        }
        KeyFocus { id: bellKey; onActivated: Ui.notifCenter = !Ui.notifCenter }

        T {
            id: bellIcon
            anchors.centerIn: parent
            font.pixelSize: 15
            text: Notifs.dnd ? Icons.bellOff : Icons.bell
            color: Notifs.count > 0 ? Theme.tertiary : Theme.fg
        }
        Rectangle {
            visible: Notifs.count > 0
            width: 6; height: 6; radius: 3
            color: Theme.tertiary
            x: bellIcon.x + bellIcon.width - 2
            y: bellIcon.y + 4
        }

        Tip {
            target: bell
            show: bell.containsMouse || bellKey.activeFocus
            text: (Notifs.count ? `${Notifs.count} notification${Notifs.count > 1 ? "s" : ""}` : "No notifications")
                  + (Notifs.dnd ? " · do not disturb" : "")
                  + `<br><font color='${Theme.fgDim}'>click: open · right: do not disturb</font>`
        }
    }
}
