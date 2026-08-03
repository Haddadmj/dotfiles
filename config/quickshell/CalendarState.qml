pragma Singleton

import Quickshell

// State behind the calendar popup that drops out of the bar clock.
Singleton {
    id: root

    property bool open: false
    property var activeScreen: null

    // Screen x the popup centres itself under -- the clock hands us its own
    // position on click, so the popup follows the module instead of sitting at
    // a hardcoded offset that drifts whenever the left pill's contents change.
    property real anchorX: 0

    // Month currently on display. Kept separate from `today` so paging around
    // does not lose track of which cell to highlight.
    property int viewYear: 0
    property int viewMonth: 0

    // Recomputed on open rather than ticked: the popup is short-lived, and a
    // timer running all day just to catch midnight is not worth the wakeups.
    property date today: new Date()

    readonly property var monthNames: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]

    readonly property string title: monthNames[viewMonth] + " " + viewYear

    function show(screen, x) {
        Apps.closeAll();

        root.today = new Date();
        root.viewYear = root.today.getFullYear();
        root.viewMonth = root.today.getMonth();

        root.activeScreen = screen;
        root.anchorX = x;
        root.open = true;
    }

    function close() {
        root.open = false;
    }

    function toggle(screen, x) {
        if (root.open) root.close();
        else root.show(screen, x);
    }

    function step(months) {
        // Let the Date constructor normalise the rollover -- month 12 becomes
        // January of the next year, month -1 becomes the previous December.
        const d = new Date(root.viewYear, root.viewMonth + months, 1);
        root.viewYear = d.getFullYear();
        root.viewMonth = d.getMonth();
    }

    function goToday() {
        root.today = new Date();
        root.viewYear = root.today.getFullYear();
        root.viewMonth = root.today.getMonth();
    }

    // Always 42 cells (6 weeks), so the popup keeps one height no matter how
    // the month falls. Days spilling in from the neighbouring months are kept
    // and dimmed rather than blanked, which reads better across a month edge.
    function cells() {
        const first = new Date(viewYear, viewMonth, 1);
        const lead = first.getDay(); // 0 = Sunday
        const out = [];

        for (let i = 0; i < 42; i++) {
            const d = new Date(viewYear, viewMonth, 1 + i - lead);
            out.push({
                day: d.getDate(),
                inMonth: d.getMonth() === viewMonth,
                isToday: d.getFullYear() === today.getFullYear()
                    && d.getMonth() === today.getMonth()
                    && d.getDate() === today.getDate()
            });
        }

        return out;
    }
}
