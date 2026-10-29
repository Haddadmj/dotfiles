import QtQuick
import qs

// Drop inside any clickable item to make it keyboard-reachable: in the Tab chain,
// Enter/Space emit activated(), arrows/Tab move on, and a ring is drawn while focused.
// Usage: KeyFocus { onActivated: doThing() }   (set `enabled: false` to drop it from the chain)
Rectangle {
    signal activated()
    anchors.fill: parent
    radius: parent.radius ?? 0
    color: "transparent"
    border.width: 2
    border.color: Theme.fg
    // dark inner line so the ring shows on light (primary) and dark islands alike
    Rectangle { anchors.fill: parent; anchors.margins: 2; radius: Math.max(0, parent.radius - 2); color: "transparent"; border.width: 1; border.color: Theme.bg }
    opacity: activeFocus ? 1 : 0    // not `visible`: hidden items cannot take focus
    activeFocusOnTab: true
    Keys.onReturnPressed: activated()
    Keys.onEnterPressed: activated()
    Keys.onSpacePressed: activated()
    // arrows walk the Tab chain too; a parent that handles arrows itself (grids) sees them first only if it's focused
    Keys.onLeftPressed: nextItemInFocusChain(false).forceActiveFocus()
    Keys.onUpPressed: nextItemInFocusChain(false).forceActiveFocus()
    Keys.onRightPressed: nextItemInFocusChain(true).forceActiveFocus()
    Keys.onDownPressed: nextItemInFocusChain(true).forceActiveFocus()
}
