import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs
import qs.components

// Lock screen: blurred wallpaper, clock, now playing, password (PAM, same config as hyprlock).
// Lock with `qs ipc call lock lock`. Typing anywhere goes to the password field.
Scope {
    id: root
    property string wallpaper: ""
    property string password: ""
    property string status: ""
    property bool failed: false
    signal cleared()

    FileView {
        path: Quickshell.env("HOME") + "/.cache/theme-state"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.wallpaper = text().split("\n")[0]
    }

    PamContext {
        id: pam
        config: "hyprlock"
        onResponseRequiredChanged: if (responseRequired) { respond(root.password); root.cleared() }
        onMessageChanged: if (messageIsError) root.status = message
        onCompleted: result => {
            if (result === PamResult.Success) { Ui.locked = false; root.status = ""; root.failed = false }
            else { root.status = "Wrong password"; root.failed = true; shake.restart() }
        }
        onError: root.status = "Authentication error"
    }

    function submit() {
        if (pam.active || password === "") return
        status = "Checking…"
        failed = false
        pam.start()
    }

    // auto-unlock while typing: unix_chkpwd checks silently (no faillock strikes), real PAM runs only once it matches
    Process {
        id: check
        property string tried: ""
        command: ["unix_chkpwd", Quickshell.env("USER"), "nullok"]
        stdinEnabled: true
        onStarted: { write(tried + "\0"); stdinEnabled = false }
        onExited: code => {
            stdinEnabled = true
            if (tried !== root.password) checkDelay.restart()
            else if (code === 0) root.submit()
        }
    }
    Timer {
        id: checkDelay
        interval: 150
        onTriggered: if (!check.running && root.password && !pam.active) { check.tried = root.password; check.running = true }
    }

    SequentialAnimation { id: shake; loops: 2
        NumberAnimation { target: root; property: "shakeX"; to: 12; duration: 50 }
        NumberAnimation { target: root; property: "shakeX"; to: -12; duration: 80 }
        NumberAnimation { target: root; property: "shakeX"; to: 0; duration: 50 }
    }
    property real shakeX: 0

    WlSessionLock {
        locked: Ui.locked

        WlSessionLockSurface {
            id: surface
            color: Theme.bg

            SystemClock { id: clock; precision: SystemClock.Seconds }

            Image {
                id: wall
                anchors.fill: parent
                source: root.wallpaper ? "file://" + root.wallpaper : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
            }
            MultiEffect {
                anchors.fill: parent
                source: wall
                blurEnabled: true
                blur: 1
                blurMax: 64
                brightness: -0.15
            }
            Rectangle { anchors.fill: parent; color: Theme.alpha(Theme.bg, 0.35) }

            // keep focus on the input whatever is clicked
            MouseArea { anchors.fill: parent; onClicked: input.forceActiveFocus() }

            ColumnLayout {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.22
                spacing: 0
                T {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatTime(clock.date, "hh:mm")
                    font.pixelSize: 128
                    font.weight: Font.Bold
                    color: Theme.fg
                }
                T {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDate(clock.date, "dddd, d MMMM")
                    font.pixelSize: 22
                    font.weight: Font.Normal
                    color: Theme.fgDim
                }
            }

            ColumnLayout {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: root.shakeX
                y: parent.height * 0.58
                spacing: 12

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 360
                    implicitHeight: 52
                    radius: 26
                    color: Theme.alpha(Theme.bg, 0.7)
                    border.width: 2
                    border.color: root.failed ? Theme.error : input.activeFocus ? Theme.primary : Theme.islandBorder
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.rightMargin: 20
                        spacing: 12
                        T { text: pam.active ? Icons.refresh : Icons.lock; color: Theme.primary; font.pixelSize: 18 }
                        TextInput {
                            id: input
                            Layout.fillWidth: true
                            focus: true
                            echoMode: TextInput.Password
                            passwordCharacter: "●"
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: 16
                            enabled: !pam.active
                            onTextChanged: { root.password = text; if (text) { root.failed = false; checkDelay.restart() } }
                            Keys.onReturnPressed: root.submit()
                            Keys.onEnterPressed: root.submit()
                            Keys.onEscapePressed: text = ""
                            Connections { target: root; function onCleared() { input.text = "" } }
                            Component.onCompleted: forceActiveFocus()
                            T {
                                visible: !input.text
                                text: "Password"
                                color: Theme.alpha(Theme.fg, 0.4)
                                font.pixelSize: 16
                                font.weight: Font.Normal
                            }
                        }
                    }
                }
                T {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.status || Quickshell.env("USER")
                    color: root.failed ? Theme.error : Theme.fgDim
                    font.weight: Font.Normal
                }
            }

            // bottom: now playing + notifications
            RowLayout {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 40
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 24
                RowLayout {
                    visible: Media.active !== null && (Media.active?.trackTitle ?? "") !== ""
                    spacing: 10
                    T { text: Icons.music; color: Theme.primary }
                    T {
                        text: [Media.active?.trackTitle, Media.active?.trackArtist].filter(s => s).join(" · ")
                        font.weight: Font.Normal
                        Layout.maximumWidth: 500
                        elide: Text.ElideRight
                    }
                    T {
                        text: Media.active?.isPlaying ? Icons.pause : Icons.play
                        MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: Media.active.togglePlaying() }
                    }
                }
                T {
                    visible: Notifs.count > 0
                    text: `${Icons.bell}  ${Notifs.count}`
                    color: Theme.tertiary
                }
            }
        }
    }
}
