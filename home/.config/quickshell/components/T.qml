import QtQuick
import qs

// Text in the bar's font
Text {
    color: Theme.fg
    font.family: Theme.font
    font.pixelSize: Theme.fontSize
    font.weight: Font.DemiBold
    verticalAlignment: Text.AlignVCenter
    Behavior on color { ColorAnimation { duration: Theme.anim } }
}
