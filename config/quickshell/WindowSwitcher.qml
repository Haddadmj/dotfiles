import QtQuick
import Quickshell
import Quickshell.Wayland

// Alt-tab style window switcher, opened with SUPER + TAB.
//
// It is a press-and-pick switcher, not a hold-and-release one: Hyprland hands a
// layer surface the whole keyboard, and there is no key-up event for SUPER to
// hook, so the overlay stays up until Enter or Escape. Tab keeps cycling while
// it is open, which is close enough to muscle memory that it does not matter.
PanelWindow {
    id: switcher

    required property var modelData
    screen: modelData

    visible: Switcher.open && Switcher.activeScreen === modelData

    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:switcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    readonly property var entries: Switcher.entries

    onVisibleChanged: {
        if (!visible) return;

        // Preselect the previously focused window, the way alt-tab does -- the
        // snapshot is MRU-ordered, so that is index 1 whenever it exists.
        row.currentIndex = switcher.entries.length > 1 ? 1 : 0;
        keys.forceActiveFocus();
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.scrim

        MouseArea {
            anchors.fill: parent
            onClicked: Switcher.close()
        }
    }

    FocusScope {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: Switcher.close()
        Keys.onReturnPressed: Switcher.focus(row.currentItem ? row.currentItem.toplevel : null)
        Keys.onEnterPressed: Switcher.focus(row.currentItem ? row.currentItem.toplevel : null)

        Keys.onPressed: event => {
            const count = switcher.entries.length;
            if (count === 0) return;

            // Backtab is what shift+tab arrives as.
            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
                row.currentIndex = (row.currentIndex + 1) % count;
                event.accepted = true;
            } else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
                row.currentIndex = (row.currentIndex - 1 + count) % count;
                event.accepted = true;
            }
        }

        Rectangle {
            anchors.centerIn: parent
            visible: switcher.entries.length > 0

            width: Math.min(row.contentWidth + 40, switcher.width - 120)
            height: 190
            radius: 20
            color: Colors.surface
            border.width: 1
            border.color: Colors.border

            ListView {
                id: row
                anchors.fill: parent
                anchors.margins: 20
                orientation: ListView.Horizontal
                spacing: 0
                clip: true
                highlightMoveDuration: 140

                model: switcher.entries

                delegate: Item {
                    id: card
                    required property var modelData
                    required property int index

                    // A toplevel destroyed while the switcher still holds it in
                    // its snapshot arrives here as null, so every read of it
                    // has to tolerate that.
                    readonly property var toplevel: modelData
                    readonly property string cls: (toplevel && toplevel.lastIpcObject
                        && toplevel.lastIpcObject.class) || ""
                    readonly property string label: (toplevel && toplevel.title) || cls
                    readonly property var workspace: toplevel ? toplevel.workspace : null

                    width: 150
                    height: row.height

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 5
                        radius: 14
                        color: card.index === row.currentIndex
                            ? Colors.hoverStrong
                            : (hover.containsMouse ? Colors.hover : "transparent")
                        border.width: card.index === row.currentIndex ? 1 : 0
                        border.color: Colors.accent

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
                            width: 56
                            height: 56
                            sourceSize.width: 56
                            sourceSize.height: 56
                            source: Apps.iconForClass(card.cls)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            asynchronous: true
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: card.label
                            color: Colors.text
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: card.workspace
                                ? "workspace " + card.workspace.name
                                : ""
                            color: Colors.textFaint
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Switcher.focus(card.toplevel)
                        onEntered: row.currentIndex = card.index
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: switcher.entries.length === 0
            text: "No open windows"
            color: Colors.textFaint
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
        }
    }
}
