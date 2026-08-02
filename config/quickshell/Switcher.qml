pragma Singleton

import Quickshell
import Quickshell.Hyprland

// State behind the SUPER + TAB window switcher.
Singleton {
    id: root

    property bool open: false
    property var activeScreen: null

    // Snapshot of the window list taken when the switcher opens. It is
    // deliberately not live: a window that maps or retitles itself mid-switch
    // would otherwise reshuffle the row under the selection.
    property var entries: []

    // Hyprland numbers windows by focusHistoryID -- 0 is the focused one, 1 the
    // one before it, and so on -- so sorting on it produces exactly alt-tab's
    // most-recently-used order for free.
    function historyId(toplevel) {
        const ipc = toplevel.lastIpcObject;
        return ipc && ipc.focusHistoryID !== undefined ? ipc.focusHistoryID : 9999;
    }

    function list() {
        return Hyprland.toplevels.values.slice().sort(
            (a, b) => root.historyId(a) - root.historyId(b));
    }

    function show(screen) {
        // Ask for fresh titles and focus order; the event socket usually has us
        // current already, so this mostly matters after the shell restarts.
        Hyprland.refreshToplevels();

        root.entries = root.list();
        root.activeScreen = screen;
        root.open = true;
    }

    function close() {
        root.open = false;
    }

    function focus(toplevel) {
        root.close();
        if (!toplevel) return;

        // `address` comes through without the 0x that the dispatcher wants.
        const address = toplevel.address.startsWith("0x")
            ? toplevel.address
            : "0x" + toplevel.address;

        // Lua form on purpose: this Hyprland runs the non-legacy parser, where
        // the old `focuswindow address:0x...` string is a syntax error.
        Hyprland.dispatch('hl.dsp.focus({window = "address:' + address + '"})');
    }
}
