pragma Singleton
import QtQuick
import Quickshell

// Nerd Font glyphs (same ones the Waybar config used)
Singleton {
    readonly property string launcher: "\u{f003b}"
    readonly property var workspaces: ({ 1: "\u{f489}", 2: "\u{e63c}", 3: "\u{f0a1e}", 4: "\u{f086}", 5: "\u{f075a}" })
    readonly property string wsDefault: "\u{f0765}"
    readonly property string wsUrgent: "\u{f0026}"
    readonly property string chevronLeft: "\u{f0141}"
    readonly property var wifi: ["\u{f092f}", "\u{f091f}", "\u{f0922}", "\u{f0925}", "\u{f0928}"]
    readonly property string ethernet: "\u{f0200}"
    readonly property string offline: "\u{f092e}"
    readonly property string down: "\u{f0045}"
    readonly property string up: "\u{f005d}"
    readonly property string bt: "\u{f00af}"
    readonly property string btOff: "\u{f00b2}"
    readonly property string btConnected: "\u{f00b1}"
    readonly property string bell: "\u{f009a}"
    readonly property string bellOff: "\u{f009b}"
    readonly property string muted: "\u{f075f}"
    readonly property string mic: "\u{f036c}"
    readonly property string micOff: "\u{f036d}"
    readonly property string headphone: "\u{f02cb}"
    readonly property string headset: "\u{f02ce}"
    readonly property var volume: ["\u{f057f}", "\u{f0580}", "\u{f057e}"]
    readonly property string calendar: "\u{f00ed}"
    readonly property string clock: "\u{f0150}"
    readonly property string power: "\u{23fb}"
    readonly property string lock: "\u{f033e}"
    readonly property string logout: "\u{f0343}"
    readonly property string suspend: "\u{f04b2}"
    readonly property string reboot: "\u{f0709}"
    readonly property string shutdown: "\u{f0425}"
    readonly property string close: "\u{f0156}"
    readonly property string search: "\u{f0349}"
    readonly property string trash: "\u{f0a7a}"
    readonly property string plus: "\u{f0415}"
    readonly property string undo: "\u{f054c}"
    readonly property string chevronUp: "\u{f0143}"
    readonly property string chevronDown: "\u{f0140}"
    readonly property string mixer: "\u{f0bec}"
    readonly property string check: "\u{f012c}"
    readonly property string play: "\u{f040a}"
    readonly property string pause: "\u{f03e4}"
    readonly property string next: "\u{f04ad}"
    readonly property string prev: "\u{f04ae}"
    readonly property string shuffle: "\u{f049d}"
    readonly property string repeat: "\u{f0456}"
    readonly property string repeatOnce: "\u{f0458}"
    readonly property string music: "\u{f075a}"
    readonly property string apps: "\u{f003b}"
    readonly property string clipboard: "\u{f014c}"
    readonly property string image: "\u{f02e9}"
    readonly property string sun: "\u{f05a8}"
    readonly property string moon: "\u{f0594}"

    readonly property string camera: "\u{f0100}"
    readonly property string record: "\u{f044a}"
    readonly property string stop: "\u{f04db}"
    readonly property string crop: "\u{f019e}"
    readonly property string window: "\u{f0614}"
    readonly property string monitor: "\u{f0379}"
    readonly property string pencil: "\u{f03eb}"
    readonly property string save: "\u{f0193}"
    readonly property string copy: "\u{f018f}"
    readonly property string mouse: "\u{f037d}"
    readonly property string gamepad: "\u{f0297}"
    readonly property string keyboard: "\u{f030c}"
    readonly property string cpu: "\u{f0ee0}"
    readonly property string memory: "\u{f035b}"
    readonly property string gpu: "\u{f08ae}"
    readonly property string thermometer: "\u{f050f}"
    readonly property string calculator: "\u{f00ec}"
    readonly property string web: "\u{f059f}"
    readonly property string terminal: "\u{f018d}"
    readonly property string emoji: "\u{f01f2}"
    readonly property string tune: "\u{f062e}"
    readonly property string overview: "\u{f056e}"
    readonly property string lockOpen: "\u{f033f}"
    readonly property string eye: "\u{f0208}"
    readonly property string refresh: "\u{f0450}"
    readonly property string wifiOff: "\u{f092e}"
    readonly property string settings: "\u{f0493}"
    // battery 0..100% → glyph (10% steps); alert below 10
    readonly property var batteryLevels: ["\u{f0083}", "\u{f007a}", "\u{f007b}", "\u{f007c}", "\u{f007d}", "\u{f007e}", "\u{f007f}", "\u{f0080}", "\u{f0081}", "\u{f0082}", "\u{f0079}"]
    function batteryIcon(p) { return batteryLevels[Math.max(0, Math.min(10, Math.round(p / 10)))] }

    function volumeIcon(v, isMuted) {
        if (isMuted) return muted
        return volume[Math.max(0, Math.min(2, Math.floor(v * 3)))]
    }
}
