import QtQuick
import qs
import qs.components

// One dock slot. Always `maxSize` tall so the Row lines icons up along the bottom; the icon grows to `size`.
// Shows a name bubble on hover, one dot per open window, bounces while `bouncing`.
// Drag it (when `draggable`) and the panel gets dragMoved/dropped with the pointer in panel coordinates.
Item {
    id: root
    property real size: 48
    property real maxSize: 72
    property string iconName: ""      // icon name or path; empty → draw `glyph` on a tile instead
    property string glyph: ""
    property string label: ""
    property int windows: 0
    property bool active: false
    property bool bouncing: false
    property bool highlight: false    // e.g. a file dragged over the trash
    property bool draggable: false
    property bool dimmed: false
    property bool showLabel: true
    readonly property bool hovered: mouse.containsMouse
    readonly property alias dragging: mouse.dragging
    readonly property alias iconItem: icon
    signal clicked(var mouse)
    signal dragMoved(real x, real y)
    signal dropped(real x, real y)

    width: size
    height: maxSize
    Behavior on size { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

    Item {
        id: icon
        width: root.size
        height: root.size
        anchors.bottom: parent.bottom
        opacity: root.dimmed ? 0.35 : 1
        Behavior on opacity { NumberAnimation { duration: 150 } }
        transform: Translate { id: shift }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            radius: Theme.radius + 4
            color: Theme.alpha(Theme.primary, 0.25)
            border.width: 2
            border.color: Theme.primary
            visible: root.highlight
        }

        AppIcon {
            anchors.fill: parent
            visible: root.iconName !== ""
            icon: root.iconName
            scale: mouse.pressed && !mouse.dragging ? 0.88 : 1
            Behavior on scale { NumberAnimation { duration: 120 } }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: parent.width * 0.06
            visible: root.iconName === ""
            radius: width * 0.24
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.mix(Theme.primary, "#ffffff", 0.15) }
                GradientStop { position: 1; color: Theme.primaryC }
            }
            scale: mouse.pressed && !mouse.dragging ? 0.88 : 1
            Behavior on scale { NumberAnimation { duration: 120 } }
            T {
                anchors.centerIn: parent
                text: root.glyph
                color: Theme.primaryCText
                font.pixelSize: parent.width * 0.55
            }
        }
    }

    // macOS-style bounce while the app starts
    SequentialAnimation {
        running: root.bouncing
        loops: Animation.Infinite
        onStopped: shift.y = 0
        NumberAnimation { target: shift; property: "y"; to: -root.size * 0.35; duration: 260; easing.type: Easing.OutQuad }
        NumberAnimation { target: shift; property: "y"; to: 0; duration: 260; easing.type: Easing.InQuad }
        PauseAnimation { duration: 120 }
    }

    // open-window dots
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.bottom
        anchors.topMargin: 2
        spacing: 3
        Repeater {
            model: Math.min(root.windows, 3)
            Rectangle {
                width: root.active ? 6 : 4
                height: 4
                radius: 2
                color: root.active ? Theme.primary : Theme.fgDim
                Behavior on width { NumberAnimation { duration: 150 } }
            }
        }
    }

    // name bubble
    Rectangle {
        anchors.horizontalCenter: icon.horizontalCenter
        anchors.bottom: icon.top
        anchors.bottomMargin: 10
        width: name.implicitWidth + 20
        height: name.implicitHeight + 10
        radius: Theme.radius
        color: Theme.popup
        border.width: 1
        border.color: Theme.alpha(Theme.primary, 0.4)
        opacity: root.showLabel && root.hovered && !mouse.dragging && root.label !== "" && Ui.popup === "" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
        T { id: name; anchors.centerIn: parent; text: root.label; font.pixelSize: Theme.fontSize - 1 }
    }

    MouseArea {
        id: mouse
        property bool dragging: false
        property bool dragged: false   // swallow the click that follows a drop
        property point start
        anchors.fill: icon
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        preventStealing: true

        onPressed: e => { start = Qt.point(e.x, e.y); dragged = false }
        onPositionChanged: e => {
            if (!pressed || !root.draggable || !(pressedButtons & Qt.LeftButton)) return
            if (!dragging && Math.hypot(e.x - start.x, e.y - start.y) > 8) dragging = true
            if (!dragging) return
            shift.x = e.x - start.x
            shift.y = e.y - start.y
            const p = mapToItem(null, e.x, e.y)
            root.dragMoved(p.x, p.y)
        }
        onReleased: e => {
            if (!dragging) return
            const p = mapToItem(null, e.x, e.y)
            dragging = false
            dragged = true
            shift.x = 0
            shift.y = 0
            root.dropped(p.x, p.y)
        }
        onCanceled: { dragging = false; shift.x = 0; shift.y = 0 }
        onClicked: e => { if (!dragged) root.clicked(e) }
    }
}
