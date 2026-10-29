pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Notification daemon (replaces swaync). Every notification is kept in the center until dismissed;
// `popups` holds the ones currently shown as toasts.
Singleton {
    id: root
    property bool dnd: false
    property var popups: []
    property var times: ({})   // notification id → time received
    readonly property var list: [...server.trackedNotifications.values].reverse()   // newest first
    readonly property int count: server.trackedNotifications.values.length

    function hidePopup(n) { popups = popups.filter(p => p !== n) }
    function clear() { for (const n of [...server.trackedNotifications.values]) n.dismiss() }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // "now", "5m", "2h" — reads clock.date so bindings refresh every minute
    function ago(id) {
        const time = times[id]
        if (!time) return ""
        const s = (clock.date.getTime() - time) / 1000
        if (s < 60) return "now"
        if (s < 3600) return `${Math.floor(s / 60)}m`
        if (s < 86400) return `${Math.floor(s / 3600)}h`
        return `${Math.floor(s / 86400)}d`
    }

    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        actionsSupported: true
        actionIconsSupported: true
        imageSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true

        onNotification: n => {
            n.tracked = true
            root.times[n.id] = Date.now()
            n.closed.connect(() => root.hidePopup(n))
            if (!root.dnd || n.urgency === NotificationUrgency.Critical)
                root.popups = [n, ...root.popups].slice(0, 5)
        }
    }
}
