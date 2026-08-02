pragma Singleton

import QtQuick
import Quickshell

// Shared state + app-list logic behind both launchers (the GNOME-style grid on
// the dock and the Windows-style menu on the bar).
Singleton {
    id: root

    // Which launcher is open, and on which screen it was triggered from.
    property bool gridOpen: false
    property bool menuOpen: false
    property var activeScreen: null

    function openGrid(screen) {
        menuOpen = false;
        activeScreen = screen;
        gridOpen = true;
    }

    function openMenu(screen) {
        gridOpen = false;
        activeScreen = screen;
        menuOpen = true;
    }

    function closeAll() {
        gridOpen = false;
        menuOpen = false;
    }

    function iconFor(entry) {
        return Quickshell.iconPath(entry.icon, "application-x-executable");
    }

    // Icon for a window, which only tells us its WM class. heuristicLookup does
    // the fuzzy desktop-entry matching (steam, Alacritty, thunar all resolve),
    // but it misses where the class and the entry id diverge -- brave-nightly
    // ships brave-browser-nightly.desktop -- so fall back to treating the class
    // itself as an icon name before giving up on the generic one.
    function iconForClass(cls) {
        if (!cls) return Quickshell.iconPath("application-x-executable");

        const entry = DesktopEntries.heuristicLookup(cls);
        return Quickshell.iconPath(entry ? entry.icon : cls, "application-x-executable");
    }

    // Rank matches so a prefix hit on the name beats an incidental substring
    // somewhere in the description.
    function score(entry, needle) {
        const name = (entry.name || "").toLowerCase();
        if (name.startsWith(needle)) return 0;
        if (name.includes(needle)) return 1;

        const generic = (entry.genericName || "").toLowerCase();
        if (generic.includes(needle)) return 2;
        if ((entry.comment || "").toLowerCase().includes(needle)) return 3;

        // categories is a QStringList, not a string — joining keeps this a
        // plain substring test without tripping over the list type.
        const categories = Array.from(entry.categories || []).join(" ").toLowerCase();
        if (categories.includes(needle)) return 4;

        return -1;
    }

    function list(query) {
        const needle = (query || "").trim().toLowerCase();
        const out = [];

        for (const entry of DesktopEntries.applications.values) {
            if (entry.noDisplay) continue;

            if (needle === "") {
                out.push({ entry: entry, rank: 0 });
                continue;
            }

            const rank = root.score(entry, needle);
            if (rank >= 0) out.push({ entry: entry, rank: rank });
        }

        out.sort((a, b) => a.rank !== b.rank
            ? a.rank - b.rank
            : (a.entry.name || "").localeCompare(b.entry.name || ""));

        return out.map(x => x.entry);
    }

    function launch(entry) {
        if (!entry) return;
        closeAll();

        if (entry.runInTerminal) {
            Quickshell.execDetached(["alacritty", "-e"].concat(entry.command));
        } else {
            Quickshell.execDetached(entry.command);
        }
    }
}
