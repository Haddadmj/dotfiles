import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: bar

    required property var modelData
    screen: modelData

    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
    }

    margins {
        top: 5
        left: 5
        right: 5
    }

    implicitHeight: 35
    exclusiveZone: implicitHeight

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell:bar"

    Item {
        anchors.fill: parent

        // modules-left
        Rectangle {
            id: leftPill
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            height: 25
            radius: 15
            color: Colors.barBg
            width: leftRow.implicitWidth + 20

            RowLayout {
                id: leftRow
                anchors.centerIn: parent
                spacing: 10

                AppLauncher { barWindow: bar }
                Clock { barWindow: bar }
                Disk {}
                Memory {}
                Cpu {}
                ActiveWindow {}
            }
        }

        // modules-center
        Rectangle {
            anchors.centerIn: parent
            height: 25
            radius: 15
            color: Colors.barBg
            width: centerRow.implicitWidth + 20

            RowLayout {
                id: centerRow
                anchors.centerIn: parent
                spacing: 6

                Workspaces {}
            }
        }

        // modules-right
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            height: 25
            radius: 15
            color: Colors.barBg
            width: rightRow.implicitWidth + 20

            RowLayout {
                id: rightRow
                anchors.centerIn: parent
                spacing: 10

                Tray {}
                Updates {}
                GameModeIndicator {}
                Clipboard {}
                IdleInhibitorIndicator { barWindow: bar }
                BluetoothIndicator {}
                KeyboardLayout {}
                Audio {}
                Network {}
            }
        }
    }
}
