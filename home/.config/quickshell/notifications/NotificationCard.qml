import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs
import qs.components

// One notification. `toast` cards time out (hover pauses) and only leave the popup stack;
// the close button dismisses the notification everywhere. Clicking a notification without its own
// action focuses the app that sent it, if it has a window.
Rectangle {
    id: root
    required property var notif
    property bool toast: false
    readonly property bool critical: notif?.urgency === NotificationUrgency.Critical
    readonly property var defaultAction: (notif?.actions ?? []).find(a => a.identifier === "default") ?? null
    readonly property var buttons: (notif?.actions ?? []).filter(a => a.identifier !== "default")

    readonly property string image: {
        const i = notif?.image || notif?.appIcon
        if (!i) return ""
        if (i.startsWith("/")) return "file://" + i
        if (i.includes("://")) return i
        return Quickshell.iconPath(i, true)
    }
    readonly property string appIcon: {
        if (!notif?.image || !notif?.appIcon) return ""
        const e = DesktopEntries.heuristicLookup(notif.desktopEntry || notif.appName)
        return Quickshell.iconPath(e?.icon ?? notif.appIcon, true)
    }

    // a window of the sending app, matched on its class against the desktop entry / app name
    readonly property var appWindow: {
        const keys = [notif?.desktopEntry, notif?.appName].filter(k => k).map(k => k.toLowerCase())
        if (!keys.length) return null
        return Hyprland.toplevels.values.find(t => {
            const c = (t.lastIpcObject?.class ?? "").toLowerCase()
            return c && keys.some(k => c === k || c.endsWith("." + k) || c.startsWith(k + "-") || k.endsWith("." + c))
        }) ?? null
    }
    function focusApp() {
        const a = appWindow.address
        Hyprland.dispatch(`hl.dsp.focus({ window = "address:${a.startsWith("0x") ? a : "0x" + a}" })`)
        Ui.notifCenter = false
        if (toast) Notifs.hidePopup(notif)
    }

    implicitWidth: 380
    implicitHeight: content.implicitHeight + 24
    radius: Theme.radius + 2
    color: mouse.containsMouse ? Theme.mix(Theme.popup, Theme.secondary, 0.35) : Theme.popup
    border.width: 1
    border.color: critical ? Theme.error : Theme.alpha(Theme.primary, toast ? 0.35 : 0.15)
    Behavior on color { ColorAnimation { duration: 150 } }

    Timer {
        running: root.toast && !root.critical && !mouse.containsMouse
        interval: root.notif?.expireTimeout > 0 ? root.notif?.expireTimeout : 5000
        onTriggered: {
            if (root.notif?.transient) root.notif?.expire()
            else Notifs.hidePopup(root.notif)
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: root.defaultAction || root.appWindow ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: e => {
            if (e.button === Qt.MiddleButton) root.notif?.dismiss()
            else if (root.defaultAction) { root.defaultAction.invoke(); Ui.notifCenter = false }
            else if (root.appWindow) root.focusApp()
            else if (root.toast) Notifs.hidePopup(root.notif)
        }
    }

    RowLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 12

        Item {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 44
            implicitHeight: 44
            visible: root.image !== ""
            ClippingRectangle {
                anchors.fill: parent
                radius: 8
                color: "transparent"
                Image {
                    anchors.fill: parent
                    source: root.image
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(88, 88)
                    asynchronous: true
                }
            }
            IconImage {
                visible: root.appIcon !== ""
                source: root.appIcon
                implicitSize: 18
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: -4
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            RowLayout {
                Layout.fillWidth: true
                T {
                    Layout.fillWidth: true
                    text: root.notif?.summary || root.notif?.appName || ""
                    elide: Text.ElideRight
                    color: root.critical ? Theme.error : Theme.fg
                }
                T {
                    text: [root.notif?.appName, Notifs.ago(root.notif?.id)].filter(s => s).join(" · ")
                    font.pixelSize: 11
                    font.weight: Font.Normal
                    color: Theme.fgDim
                }
                T {
                    text: Icons.close
                    font.pixelSize: 14
                    color: closeMouse.containsMouse ? Theme.error : Theme.fgDim
                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.notif?.dismiss()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.notif?.body ?? ""
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: root.toast ? 4 : 8
                elide: Text.ElideRight
                color: Theme.fgDim
                linkColor: Theme.primary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 1
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                visible: root.buttons.length > 0
                spacing: 6
                Repeater {
                    model: root.buttons
                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 28
                        radius: 7
                        color: btnMouse.containsMouse ? Theme.primary : Theme.alpha(Theme.secondary, 0.8)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        T {
                            anchors.centerIn: parent
                            width: parent.width - 12
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: modelData.text
                            color: btnMouse.containsMouse ? Theme.primaryText : Theme.fg
                        }
                        MouseArea {
                            id: btnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: modelData.invoke()
                        }
                    }
                }
            }
        }
    }
}
