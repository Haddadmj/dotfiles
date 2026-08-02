import QtQuick
import Quickshell

// Bar launcher — opens the Windows-style start menu.
Text {
    id: launcher

    required property var barWindow

    // nf-fa-th (grid), written as an escape so the private-use
    // glyph cannot be lost by a future rewrite of this file.
    text: ""
    color: Apps.menuOpen ? Colors.accent : Colors.text
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 16

    Behavior on color {
        ColorAnimation { duration: 100 }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (Apps.menuOpen) Apps.closeAll();
            else Apps.openMenu(launcher.barWindow.screen);
        }
    }
}
