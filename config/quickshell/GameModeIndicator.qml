import QtQuick

// Game-mode toggle. Dim when off, accent when on; clicking it is the same as
// pressing SUPER + ALT + G.
Text {
    text: ""  // nf-fa-gamepad
    color: GameMode.active ? Colors.accent : Colors.textFaint
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 14

    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: GameMode.toggle()
    }
}
