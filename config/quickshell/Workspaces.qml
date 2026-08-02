import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

RowLayout {
    spacing: 6

    readonly property string inactiveIcon: ""
    readonly property string activeIcon: ""

    Repeater {
        model: 6

        Text {
            required property int index

            readonly property int wsId: index + 1
            readonly property var hw: {
                for (const w of Hyprland.workspaces.values) {
                    if (w.id === wsId) return w;
                }
                return null;
            }

            text: hw && hw.focused ? activeIcon : inactiveIcon
            color: hw && hw.focused ? Colors.accent : Colors.text
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch("hl.dsp.focus({workspace = " + wsId + "})")
            }
        }
    }
}
