import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components

Island {
    id: root
    padding: 14
    color: hovered || Ui.popup === "power" ? Theme.error : Theme.tertiary
    border.width: 0

    clickable: true
    onClicked: Ui.toggle("power")

    T {
        text: Icons.power
        font.pixelSize: 15
        color: root.hovered || Ui.popup === "power" ? Theme.errorText : Theme.tertiaryText
    }

    BarPopup {
        target: root
        name: "power"
        align: 1
        padding: 6

        component Action: MenuItem {
            property var command
            onClicked: { Ui.popup = ""; Quickshell.execDetached(["sh", "-c", command]) }
        }

        Action { icon: Icons.lock;     text: "Lock";      command: "loginctl lock-session" }
        Action { icon: Icons.logout;   text: "Log out";   command: "command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'" }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.islandBorder; Layout.margins: 4 }
        Action { icon: Icons.suspend;  text: "Suspend";   command: "systemctl suspend" }
        Action { icon: Icons.reboot;   text: "Reboot";    command: "systemctl reboot";   hoverColor: Theme.error; hoverText: Theme.errorText }
        Action { icon: Icons.shutdown; text: "Shut down"; command: "systemctl poweroff"; hoverColor: Theme.error; hoverText: Theme.errorText }
    }
}
