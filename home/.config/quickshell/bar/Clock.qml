import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components

// Date + time. Click: calendar (scroll or arrows to change month, click the title: back to today)
Island {
    id: root
    color: hovered ? Theme.alpha(Theme.primaryC, 0.8) : Theme.primaryC
    border.width: 0

    SystemClock { id: clock; precision: SystemClock.Minutes }

    clickable: true
    onClicked: Ui.toggle("calendar")

    T {
        color: Theme.primaryCText
        text: `${Icons.calendar} ${Qt.formatDate(clock.date, "yyyy-MM-dd")}   ${Icons.clock} ${Qt.formatTime(clock.date, "hh:mm AP")}`
    }

    BarPopup {
        id: popup
        target: root
        name: "calendar"
        align: 0.5
        padding: 14

        property date today: clock.date
        property int year: today.getFullYear()
        property int month: today.getMonth()
        onOpenChanged: if (open) { year = today.getFullYear(); month = today.getMonth() }

        function shift(n) {
            const d = new Date(year, month + n, 1)
            year = d.getFullYear(); month = d.getMonth()
        }
        // 6 weeks starting on Sunday, like Waybar's calendar
        readonly property var days: {
            const first = new Date(year, month, 1)
            const start = new Date(year, month, 1 - first.getDay())
            const out = []
            for (let i = 0; i < 42; i++) out.push(new Date(start.getFullYear(), start.getMonth(), start.getDate() + i))
            return out
        }

        RowLayout {
            Layout.fillWidth: true
            T {
                text: Icons.chevronLeft
                font.pixelSize: 16
                color: Theme.fgDim
                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: popup.shift(-1) }
            }
            T {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: Qt.formatDate(new Date(popup.year, popup.month, 1), "MMMM yyyy")
                color: Theme.primary
                font.pixelSize: 15
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { popup.year = popup.today.getFullYear(); popup.month = popup.today.getMonth() } }
            }
            T {
                text: Icons.chevronLeft
                rotation: 180
                font.pixelSize: 16
                color: Theme.fgDim
                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: popup.shift(1) }
            }
        }

        GridLayout {
            columns: 7
            rowSpacing: 2
            columnSpacing: 2

            Repeater {
                model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                T {
                    required property string modelData
                    text: modelData
                    color: Theme.fgDim
                    Layout.preferredWidth: 36
                    horizontalAlignment: Text.AlignHCenter
                }
            }
            Repeater {
                model: popup.days
                Rectangle {
                    required property var modelData
                    readonly property bool isToday: modelData.toDateString() === popup.today.toDateString()
                    readonly property bool inMonth: modelData.getMonth() === popup.month
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 30
                    radius: 7
                    color: isToday ? Theme.primary : "transparent"
                    T {
                        anchors.centerIn: parent
                        text: modelData.getDate()
                        font.weight: isToday ? Font.Bold : Font.Normal
                        color: isToday ? Theme.primaryText : Theme.alpha(Theme.fg, inMonth ? 1 : 0.3)
                    }
                }
            }
        }

        WheelHandler { onWheel: e => popup.shift(e.angleDelta.y > 0 ? -1 : 1) }
    }
}
