import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs
import qs.components

// Battery of wireless devices (mouse, controller, headset…) from UPower, plus
// USB-dongle headsets that only headsetcontrol can read (polled every minute).
// Hidden when none are connected. Sends a notification at 20% and 10%.
Island {
    id: root
    readonly property var devices: UPower.devices.values.filter(d => !d.isLaptopBattery && d.isPresent
        && d.type !== UPowerDeviceType.LinePower && d.type !== UPowerDeviceType.Battery && d.model).concat(headsets)
    // plain objects shaped like UPower devices: { model, percentage, type, state }
    property var headsets: []
    visible: devices.length > 0
    padding: 10
    spacing: 10

    function pct(d) { return Math.round(d.percentage > 1 ? d.percentage : d.percentage * 100) }
    function icon(d) {
        switch (d.type) {
        case UPowerDeviceType.Mouse: return Icons.mouse
        case UPowerDeviceType.GamingInput: return Icons.gamepad
        case UPowerDeviceType.Keyboard: return Icons.keyboard
        case UPowerDeviceType.Headset:
        case UPowerDeviceType.Headphones: return Icons.headset
        default: return Icons.bt
        }
    }
    function charging(d) { return d.state === UPowerDeviceState.Charging || d.state === UPowerDeviceState.FullyCharged }

    Repeater {
        model: root.devices
        T {
            id: dev
            required property var modelData
            readonly property int p: root.pct(modelData)
            readonly property bool low: p <= 20 && !root.charging(modelData)
            text: `${root.icon(modelData)} ${p}%`
            color: low ? Theme.error : Theme.fg

            // warn once per threshold, reset when it charges back up
            property int warned: 100
            onPChanged: {
                if (root.charging(modelData) || p > 25) { warned = 100; return }
                const level = p <= 10 ? 10 : p <= 20 ? 20 : 100
                if (level < warned) {
                    warned = level
                    Quickshell.execDetached(["notify-send", "-a", "Battery", "-u", level <= 10 ? "critical" : "normal",
                        `${modelData.model} battery low`, `${p}% left`])
                }
            }
            Component.onCompleted: pChanged()
        }
    }

    Process {
        id: hsPoll
        command: ["headsetcontrol", "-b", "-o", "json"]
        stdout: StdioCollector {
            onStreamFinished: {
                let list = []
                try {
                    list = JSON.parse(text).devices
                        .filter(d => d.battery && ["BATTERY_AVAILABLE", "BATTERY_CHARGING"].includes(d.battery.status))
                        .map(d => ({
                            model: d.product,
                            percentage: d.battery.level,
                            type: UPowerDeviceType.Headset,
                            state: d.battery.status === "BATTERY_CHARGING" ? UPowerDeviceState.Charging : UPowerDeviceState.Discharging
                        }))
                } catch (e) {}
                // only reassign on change so the Repeater keeps its delegates (and their low-battery warning state)
                if (JSON.stringify(list) !== JSON.stringify(root.headsets)) root.headsets = list
            }
        }
    }
    Timer {
        interval: 60000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: hsPoll.running = true
    }

    Tip {
        target: root
        show: root.hovered
        text: root.devices.map(d => `${root.icon(d)}  ${d.model}  <b>${root.pct(d)}%</b>${root.charging(d) ? " ⚡" : ""}`).join("<br>")
    }
}
