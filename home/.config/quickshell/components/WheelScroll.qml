import QtQuick

// Faster, smooth mouse-wheel scrolling for a Flickable / ListView / GridView (Qt's default steps
// are small and slow). Declare it inside the view (it lands in the content item, so it sees the
// wheel before the view does):  WheelScroll { view: list }
// Touchpads scroll by pixel delta (x touchSpeed); wheel notches glide with an eased animation.
WheelHandler {
    id: root
    required property Flickable view
    property real speed: 3              // px per wheel unit; one notch = 120 → 360px
    property real touchSpeed: 2

    function clamp(y) {
        return Math.max(view.originY, Math.min(view.originY + Math.max(0, view.contentHeight - view.height), y))
    }

    onWheel: e => {
        if (e.pixelDelta.y !== 0) {
            anim.stop()
            view.contentY = clamp(view.contentY - e.pixelDelta.y * touchSpeed)
        } else {
            // keep accumulating from where the running animation is heading
            const from = anim.running ? anim.to : view.contentY
            anim.stop()
            anim.from = view.contentY
            anim.to = clamp(from - e.angleDelta.y * speed)
            anim.start()
        }
        e.accepted = true
    }

    property NumberAnimation anim: NumberAnimation {
        target: root.view
        property: "contentY"
        duration: 220
        easing.type: Easing.OutCubic
    }
}
