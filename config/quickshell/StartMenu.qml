import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland

// Windows-style start menu, opened from the bar launcher. Drops down from the
// top-left under the bar, with a search box and a scrolling app list.
PanelWindow {
    id: menu

    required property var modelData
    screen: modelData

    visible: Apps.menuOpen && Apps.activeScreen === modelData

    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:startmenu"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    readonly property var results: Apps.list(search.text)

    onVisibleChanged: {
        if (visible) {
            search.text = "";
            search.forceActiveFocus();
        }
    }

    // Transparent catcher so clicking anywhere outside the panel closes it.
    MouseArea {
        anchors.fill: parent
        onClicked: Apps.closeAll()
    }

    Rectangle {
        id: panel
        x: 15
        y: 48
        width: 380
        height: 520
        radius: 12
        color: Colors.bg
        border.width: 1
        border.color: Colors.border

        // Swallow clicks so they don't reach the dismiss catcher behind.
        MouseArea {
            anchors.fill: parent
        }

        Item {
            anchors.fill: parent
            anchors.margins: 12

            // Search field
            Rectangle {
                id: searchBox
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 36
                radius: 8
                color: Colors.surface
                border.width: search.activeFocus ? 2 : 1
                border.color: search.activeFocus ? Colors.accent : Colors.borderIdle

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf002"  // nf-fa-search
                    color: Colors.textDim
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                }

                TextInput {
                    id: search
                    anchors.fill: parent
                    anchors.leftMargin: 36
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: Colors.text
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    selectByMouse: true
                    selectionColor: Colors.accent
                    selectedTextColor: Colors.accentFg
                    clip: true

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: search.text === ""
                        text: "Search apps…"
                        color: Colors.textFaint
                        font: search.font
                    }

                    Keys.onEscapePressed: Apps.closeAll()
                    Keys.onReturnPressed: Apps.launch(listView.currentItem ? listView.currentItem.entry : null)
                    Keys.onEnterPressed: Apps.launch(listView.currentItem ? listView.currentItem.entry : null)

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Down) {
                            listView.incrementCurrentIndex();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            listView.decrementCurrentIndex();
                            event.accepted = true;
                        }
                    }

                    onTextChanged: listView.currentIndex = 0
                }
            }

            Text {
                id: resultLabel
                anchors.top: searchBox.bottom
                anchors.topMargin: 10
                anchors.left: parent.left
                text: search.text === "" ? "All apps" : (menu.results.length + " result" + (menu.results.length === 1 ? "" : "s"))
                color: Colors.textDim
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
            }

            ListView {
                id: listView
                anchors.top: resultLabel.bottom
                anchors.topMargin: 8
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                clip: true
                focus: false
                currentIndex: 0
                spacing: 2
                model: menu.results

                ScrollBar.vertical: ScrollBar {}

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index

                    readonly property var entry: modelData

                    width: listView.width
                    height: 40
                    radius: 8
                    color: row.index === listView.currentIndex
                        ? Colors.hoverStrong
                        : (rowHover.containsMouse ? Colors.hover : "transparent")

                    Row {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 24
                            height: 24
                            sourceSize.width: 24
                            sourceSize.height: 24
                            source: Apps.iconFor(row.entry)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            asynchronous: true
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: row.width - 64
                            text: row.entry.name || ""
                            color: Colors.text
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: rowHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Apps.launch(row.entry)
                        onEntered: listView.currentIndex = row.index
                    }
                }
            }
        }
    }
}
