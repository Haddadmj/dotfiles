import QtQuick
import qs
import qs.components

// Opens quick settings (SUPER+A). Right click: Hyprland settings (SUPER+,).
Island {
    id: root
    padding: 12
    readonly property bool active: Ui.quickSettings || hovered
    color: active ? Theme.primary : Theme.island
    border.width: active ? 0 : 1

    clickable: true
    onClicked: e => {
        if (e.button === Qt.RightButton) { Ui.closeAll(); Ui.hyprSettings = true }
        else { Ui.popup = ""; Ui.quickSettings = !Ui.quickSettings }
    }

    // iOS control center glyph: two toggle switches, knobs on opposite sides
    Column {
        id: glyph
        readonly property color ink: root.active ? Theme.primaryText : Theme.fg
        spacing: 3
        Repeater {
            model: [false, true]
            Rectangle {
                required property bool modelData
                width: 18; height: 8; radius: 4
                color: "transparent"
                border.width: 1.5
                border.color: glyph.ink
                Rectangle {
                    x: parent.modelData ? parent.width - width : 0
                    width: 8; height: 8; radius: 4
                    color: glyph.ink
                }
                Behavior on border.color { ColorAnimation { duration: Theme.anim } }
            }
        }
    }

    Tip {
        target: root
        show: root.hovered && !Ui.quickSettings
        text: `Quick settings<br><font color='${Theme.fgDim}'>right: Hyprland settings</font>`
    }
}
