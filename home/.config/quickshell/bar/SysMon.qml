import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.components

// CPU + RAM in the bar. Click: graphs for CPU, RAM, GPU (nvidia-smi) and temperatures.
// The GPU is only queried while the popup is open.
Island {
    id: root
    property real cpu: 0          // 0..1
    property real ram: 0          // 0..1
    property real ramUsed: 0      // GiB
    property real ramTotal: 0
    property real cpuTemp: 0
    property real gpu: 0
    property real gpuTemp: 0
    property real vramUsed: 0     // GiB
    property real vramTotal: 0
    property real gpuPower: 0
    property var hist: ({ cpu: [], ram: [], gpu: [] })
    property var last: null       // previous /proc/stat totals
    readonly property bool open: Ui.popup === "sysmon"

    clickable: true
    onClicked: Ui.toggle("sysmon")

    T { text: `${Icons.cpu} ${Math.round(root.cpu * 100)}%`; color: root.cpu > 0.85 ? Theme.error : Theme.fg }
    T { Layout.leftMargin: 10; text: `${Icons.memory} ${Math.round(root.ram * 100)}%`; color: root.ram > 0.9 ? Theme.error : Theme.fg }

    function push(key, v) {
        const h = Object.assign({}, hist)
        h[key] = [...h[key], v].slice(-60)
        hist = h
    }

    Process {
        id: poll
        command: ["bash", "-c", `
            head -1 /proc/stat
            grep -E '^(MemTotal|MemAvailable):' /proc/meminfo | awk '{print $2}' | paste -sd' '
            for h in /sys/class/hwmon/hwmon*; do [ "$(cat $h/name)" = k10temp ] && cat $h/temp1_input; done
            [ "$1" = 1 ] && nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total,power.draw --format=csv,noheader,nounits
            true`, "bash", root.open ? "1" : "0"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n")
                const c = l[0].split(/\s+/).slice(1).map(Number)
                const idle = c[3] + c[4], total = c.reduce((a, b) => a + b, 0)
                if (root.last) root.cpu = 1 - (idle - root.last.idle) / Math.max(1, total - root.last.total)
                root.last = { idle, total }
                const [mt, ma] = l[1].split(" ").map(Number)
                root.ram = 1 - ma / mt
                root.ramUsed = (mt - ma) / 1048576
                root.ramTotal = mt / 1048576
                root.cpuTemp = Number(l[2] ?? 0) / 1000
                if (l[3]) {
                    const g = l[3].split(",").map(s => Number(s.trim()))
                    root.gpu = g[0] / 100; root.gpuTemp = g[1]; root.vramUsed = g[2] / 1024; root.vramTotal = g[3] / 1024; root.gpuPower = g[4]
                    root.push("gpu", root.gpu)
                }
                root.push("cpu", root.cpu)
                root.push("ram", root.ram)
            }
        }
    }
    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: root.open ? 1000 : 3000
        onTriggered: poll.running = true
    }

    Tip {
        target: root
        show: root.hovered
        text: `CPU ${Math.round(root.cpu * 100)}% · ${Math.round(root.cpuTemp)}°C<br>RAM ${root.ramUsed.toFixed(1)} / ${root.ramTotal.toFixed(1)} GiB<br><font color='${Theme.fgDim}'>click: details</font>`
    }

    BarPopup {
        target: root
        name: "sysmon"
        align: 0.5
        padding: 14

        component Graph: ColumnLayout {
            id: g
            property string icon
            property string title
            property string value
            property string detail: ""
            property var points: []
            property color accent: Theme.primary
            spacing: 4
            Layout.preferredWidth: 340

            RowLayout {
                T { text: `${g.icon}  ${g.title}`; color: g.accent; Layout.fillWidth: true }
                T { text: g.detail; color: Theme.fgDim; font.weight: Font.Normal; font.pixelSize: 11 }
                T { text: g.value; Layout.leftMargin: 8 }
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 54
                radius: 8
                color: Theme.alpha(Theme.secondary, 0.4)
                clip: true
                Canvas {
                    id: canvas
                    anchors.fill: parent
                    property var points: g.points
                    onPointsChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        const n = 60, step = width / (n - 1)
                        const pts = points.slice(-n)
                        if (pts.length < 2) return
                        const x0 = width - (pts.length - 1) * step
                        ctx.beginPath()
                        ctx.moveTo(x0, height)
                        pts.forEach((v, i) => ctx.lineTo(x0 + i * step, height - Math.max(0, Math.min(1, v)) * (height - 4)))
                        ctx.lineTo(width, height)
                        ctx.closePath()
                        ctx.fillStyle = Theme.alpha(g.accent, 0.25)
                        ctx.fill()
                        ctx.beginPath()
                        pts.forEach((v, i) => {
                            const x = x0 + i * step, y = height - Math.max(0, Math.min(1, v)) * (height - 4)
                            i ? ctx.lineTo(x, y) : ctx.moveTo(x, y)
                        })
                        ctx.strokeStyle = g.accent
                        ctx.lineWidth = 2
                        ctx.stroke()
                    }
                }
            }
        }

        Graph {
            icon: Icons.cpu; title: "CPU"; points: root.hist.cpu
            value: `${Math.round(root.cpu * 100)}%`
            detail: `${Math.round(root.cpuTemp)}°C`
        }
        Graph {
            icon: Icons.memory; title: "Memory"; points: root.hist.ram; accent: Theme.tertiary
            value: `${Math.round(root.ram * 100)}%`
            detail: `${root.ramUsed.toFixed(1)} / ${root.ramTotal.toFixed(1)} GiB`
        }
        Graph {
            icon: Icons.gpu; title: "GPU"; points: root.hist.gpu; accent: Theme.secondaryText
            value: `${Math.round(root.gpu * 100)}%`
            detail: `${Math.round(root.gpuTemp)}°C · ${root.vramUsed.toFixed(1)} / ${root.vramTotal.toFixed(0)} GiB · ${Math.round(root.gpuPower)} W`
        }
        MenuItem {
            icon: Icons.tune
            text: "Open btop"
            onClicked: { Ui.popup = ""; Quickshell.execDetached(["ghostty", "-e", "btop"]) }
        }
    }
}
