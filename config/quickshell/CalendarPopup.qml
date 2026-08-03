import QtQuick
import Quickshell
import Quickshell.Wayland

// Month view dropped from the bar clock. Same shape as StartMenu: a
// full-screen overlay whose only job is to catch the click that dismisses it,
// with the actual panel positioned inside.
PanelWindow {
    id: popup

    required property var modelData
    screen: modelData

    visible: CalendarState.open && CalendarState.activeScreen === modelData

    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:calendar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    readonly property int cellSize: 34
    readonly property var weekdays: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    // Transparent catcher so clicking anywhere outside the panel closes it.
    MouseArea {
        anchors.fill: parent
        onClicked: CalendarState.close()
    }

    Rectangle {
        id: panel

        width: 7 * popup.cellSize + 24
        height: header.height + weekRow.height + grid.height + 40

        // Centre under the clock, but never let the panel hang off the edge.
        x: Math.max(10, Math.min(CalendarState.anchorX - width / 2,
                                 popup.width - width - 10))
        y: 48

        radius: 12
        color: Colors.bg
        border.width: 1
        border.color: Colors.border

        // Swallow clicks so they don't reach the dismiss catcher behind.
        MouseArea {
            anchors.fill: parent
        }

        Keys.onEscapePressed: CalendarState.close()
        focus: popup.visible

        // Month header: ‹ August 2026 ›
        Item {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 12
            height: 28

            Text {
                id: prev
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 24
                horizontalAlignment: Text.AlignHCenter
                text: "‹"
                color: prevHover.containsMouse ? Colors.accent : Colors.textDim
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 18

                MouseArea {
                    id: prevHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: CalendarState.step(-1)
                }
            }

            Text {
                anchors.centerIn: parent
                text: CalendarState.title
                color: Colors.text
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                font.bold: true

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: CalendarState.goToday()
                }
            }

            Text {
                id: next
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 24
                horizontalAlignment: Text.AlignHCenter
                text: "›"
                color: nextHover.containsMouse ? Colors.accent : Colors.textDim
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 18

                MouseArea {
                    id: nextHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: CalendarState.step(1)
                }
            }
        }

        Row {
            id: weekRow
            anchors.top: header.bottom
            anchors.topMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            height: 20

            Repeater {
                model: popup.weekdays

                Text {
                    required property string modelData

                    width: popup.cellSize
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Colors.textFaint
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                }
            }
        }

        Grid {
            id: grid
            anchors.top: weekRow.bottom
            anchors.topMargin: 4
            anchors.horizontalCenter: parent.horizontalCenter
            columns: 7
            height: 6 * popup.cellSize

            Repeater {
                model: CalendarState.open ? CalendarState.cells() : []

                Rectangle {
                    id: cell
                    required property var modelData

                    width: popup.cellSize
                    height: popup.cellSize
                    radius: width / 2
                    color: modelData.isToday ? Colors.accent
                        : (cellHover.containsMouse ? Colors.hover : "transparent")

                    Text {
                        anchors.centerIn: parent
                        text: cell.modelData.day
                        color: cell.modelData.isToday ? Colors.accentFg
                            : (cell.modelData.inMonth ? Colors.text : Colors.textFaint)
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        font.bold: cell.modelData.isToday
                    }

                    MouseArea {
                        id: cellHover
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                }
            }
        }
    }
}
