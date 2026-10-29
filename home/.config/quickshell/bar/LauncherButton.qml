import QtQuick
import Quickshell
import qs
import qs.components

Island {
    padding: 13
    color: hovered ? Theme.alpha(Theme.primary, 0.8) : Theme.primary
    border.width: 0

    T { text: Icons.launcher; font.pixelSize: 17; color: Theme.primaryText }

    clickable: true
    onClicked: e => {
        if (e.button === Qt.RightButton) Quickshell.execDetached(["sh", "-c", "pkill wofi || wofi --show drun --allow-images"])
        else Ui.toggleLauncher("apps")
    }
}
