import QtQuick
import Quickshell
import Quickshell.Wayland

// GNOME-style fullscreen app grid, opened from the dock launcher.
PanelWindow {
    id: grid

    required property var modelData
    screen: modelData

    visible: Apps.gridOpen && Apps.activeScreen === modelData

    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Cover the bar and dock rather than being pushed around by them.
    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:appgrid"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    readonly property var results: Apps.list(search.text)

    onVisibleChanged: {
        if (visible) {
            search.text = "";
            search.forceActiveFocus();
        }
    }

    // Backdrop — clicking empty space dismisses, like GNOME's overview.
    Rectangle {
        anchors.fill: parent
        color: Colors.scrim

        MouseArea {
            anchors.fill: parent
            onClicked: Apps.closeAll()
        }
    }

    Item {
        anchors.fill: parent
        anchors.topMargin: 60
        anchors.bottomMargin: 40

        // Search field
        Rectangle {
            id: searchBox
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: 420
            height: 44
            radius: 22
            color: Colors.surface
            border.width: search.activeFocus ? 2 : 1
            border.color: search.activeFocus ? Colors.accent : Colors.borderIdle

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf002"  // nf-fa-search
                color: Colors.textDim
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 15
            }

            TextInput {
                id: search
                anchors.fill: parent
                anchors.leftMargin: 46
                anchors.rightMargin: 18
                verticalAlignment: TextInput.AlignVCenter
                color: Colors.text
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 15
                selectByMouse: true
                selectionColor: Colors.accent
                selectedTextColor: Colors.accentFg
                clip: true

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: search.text === ""
                    text: "Type to search…"
                    color: Colors.textFaint
                    font: search.font
                }

                Keys.onEscapePressed: Apps.closeAll()
                Keys.onReturnPressed: Apps.launch(gridView.currentItem ? gridView.currentItem.entry : null)
                Keys.onEnterPressed: Apps.launch(gridView.currentItem ? gridView.currentItem.entry : null)

                Keys.onPressed: event => {
                    // Arrow keys drive the grid selection while focus stays in the field.
                    if (event.key === Qt.Key_Right) {
                        gridView.moveCurrentIndexRight();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Left) {
                        gridView.moveCurrentIndexLeft();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Down) {
                        gridView.moveCurrentIndexDown();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up) {
                        gridView.moveCurrentIndexUp();
                        event.accepted = true;
                    }
                }

                onTextChanged: gridView.currentIndex = 0
            }
        }

        GridView {
            id: gridView
            anchors.top: searchBox.bottom
            anchors.topMargin: 40
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom

            width: Math.min(parent.width - 120, cellWidth * 7)
            cellWidth: 150
            cellHeight: 140
            clip: true
            focus: false
            currentIndex: 0
            highlightMoveDuration: 120

            model: grid.results

            delegate: Item {
                id: cell
                required property var modelData
                required property int index

                readonly property var entry: modelData

                width: gridView.cellWidth
                height: gridView.cellHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 6
                    radius: 14
                    color: cell.index === gridView.currentIndex
                        ? Colors.hoverStrong
                        : (cellHover.containsMouse ? Colors.hover : "transparent")

                    Behavior on color {
                        ColorAnimation { duration: 100 }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    width: parent.width - 20

                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 64
                        height: 64
                        sourceSize.width: 64
                        sourceSize.height: 64
                        source: Apps.iconFor(cell.entry)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        asynchronous: true
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: cell.entry.name || ""
                        color: Colors.text
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.WordWrap
                    }
                }

                MouseArea {
                    id: cellHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Apps.launch(cell.entry)
                    onEntered: gridView.currentIndex = cell.index
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: grid.results.length === 0
            text: "No matches"
            color: Colors.textFaint
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
        }
    }
}
