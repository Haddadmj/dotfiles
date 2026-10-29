import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components

// Screenshot / recording menu (SUPER+Print). Pick what to capture, then copy / save / edit (satty).
// Keys: Tab cycle region-window-screen · c copy · s save · e edit · r record · Esc close.
PanelWindow {
    id: root
    readonly property bool open: Ui.screenshot
    property string mode: "region"     // region, window, screen
    readonly property string dir: Quickshell.env("HOME") + "/Pictures/Screenshots"

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    WlrLayershell.namespace: "quickshell:screenshot"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: false

    onOpenChanged: {
        if (open) { hideTimer.stop(); visible = true; box.forceActiveFocus() }
        else hideTimer.restart()
    }
    Timer { id: hideTimer; interval: Theme.anim; onTriggered: root.visible = false }

    readonly property string hyprMode: mode === "screen" ? "-m output -m active" : `-m ${mode}`

    // close first so the menu isn't in the picture
    function shoot(action) {
        const cmd = {
            copy: `hyprshot ${hyprMode} --clipboard-only`,
            save: `hyprshot ${hyprMode} -o "${dir}"`,
            edit: `command -v satty >/dev/null || { notify-send -a Screenshot "satty is not installed" "sudo pacman -S satty"; exit 1; }
                   mkdir -p "${dir}"; hyprshot ${hyprMode} --raw | satty --filename - --output-filename "${dir}/satty-$(date +%Y-%m-%d_%H-%M-%S).png" --copy-command wl-copy`,
        }[action]
        Ui.screenshot = false
        Quickshell.execDetached(["sh", "-c", `sleep 0.35; ${cmd}`])
    }
    function record() {
        Ui.screenshot = false
        if (Recorder.recording) Recorder.stop()
        else delayRecord.restart()
    }
    Timer { id: delayRecord; interval: 350; onTriggered: Recorder.start(root.mode !== "screen") }

    MouseArea { anchors.fill: parent; onClicked: Ui.screenshot = false }

    component Choice: Rectangle {
        id: ch
        property string icon
        property string label
        property bool on: false
        property string key: ""
        signal clicked()
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 74
        radius: Theme.radius + 2
        color: on ? Theme.primary : cm.containsMouse ? Theme.alpha(Theme.secondary, 0.9) : Theme.alpha(Theme.secondary, 0.45)
        Behavior on color { ColorAnimation { duration: 150 } }
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 4
            T { Layout.alignment: Qt.AlignHCenter; text: ch.icon; font.pixelSize: 22; color: ch.on ? Theme.primaryText : Theme.fg }
            T { Layout.alignment: Qt.AlignHCenter; text: ch.label; color: ch.on ? Theme.primaryText : Theme.fg }
        }
        T {
            visible: ch.key !== ""
            anchors { top: parent.top; right: parent.right; margins: 7 }
            text: ch.key
            font.pixelSize: 10
            color: ch.on ? Theme.alpha(Theme.primaryText, 0.6) : Theme.alpha(Theme.fg, 0.4)
        }
        MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ch.clicked() }
    }

    Rectangle {
        id: box
        anchors.centerIn: parent
        width: 440
        height: col.implicitHeight + 32
        radius: Theme.radius + 4
        color: Theme.popup
        border.width: 1
        border.color: Theme.alpha(Theme.primary, 0.35)
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent }

        Keys.onPressed: e => {
            const modes = ["region", "window", "screen"]
            if (e.key === Qt.Key_Escape) Ui.screenshot = false
            else if (e.key === Qt.Key_Tab) root.mode = modes[(modes.indexOf(root.mode) + 1) % 3]
            else if (e.key === Qt.Key_Backtab) root.mode = modes[(modes.indexOf(root.mode) + 2) % 3]
            else if (e.key === Qt.Key_C || e.key === Qt.Key_Return) root.shoot("copy")
            else if (e.key === Qt.Key_S) root.shoot("save")
            else if (e.key === Qt.Key_E) root.shoot("edit")
            else if (e.key === Qt.Key_R) root.record()
            else return
            e.accepted = true
        }

        ColumnLayout {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 16
            y: 16
            spacing: 10

            T { text: `${Icons.camera}  Capture`; color: Theme.primary; font.pixelSize: 15 }
            RowLayout {
                spacing: 8
                Choice { icon: Icons.crop; label: "Region"; on: root.mode === "region"; onClicked: root.mode = "region" }
                Choice { icon: Icons.window; label: "Window"; on: root.mode === "window"; onClicked: root.mode = "window" }
                Choice { icon: Icons.monitor; label: "Screen"; on: root.mode === "screen"; onClicked: root.mode = "screen" }
            }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.islandBorder }
            RowLayout {
                spacing: 8
                Choice { icon: Icons.copy; label: "Copy"; key: "C"; onClicked: root.shoot("copy") }
                Choice { icon: Icons.save; label: "Save"; key: "S"; onClicked: root.shoot("save") }
                Choice { icon: Icons.pencil; label: "Edit"; key: "E"; onClicked: root.shoot("edit") }
                Choice {
                    icon: Recorder.recording ? Icons.stop : Icons.record
                    label: Recorder.recording ? "Stop" : "Record"
                    key: "R"
                    on: Recorder.recording
                    onClicked: root.record()
                }
            }
            T {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: "Tab switch region / window / screen · Esc close · saves to ~/Pictures/Screenshots"
                wrapMode: Text.Wrap
                color: Theme.alpha(Theme.fg, 0.4)
                font.pixelSize: 11
                font.weight: Font.Normal
            }
        }
    }
}
