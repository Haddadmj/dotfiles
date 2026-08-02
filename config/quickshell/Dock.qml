import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Wayland

PanelWindow {
    id: dock

    required property var modelData
    screen: modelData

    color: "transparent"

    anchors {
        bottom: true
    }

    implicitHeight: 60
    implicitWidth: pill.width
    exclusiveZone: 0

    // --- auto-hide ------------------------------------------------------
    // The dock sits off-screen until the pointer touches the strip at the
    // very bottom edge. Only that strip accepts input while hidden, so the
    // window underneath keeps its clicks.
    readonly property int peek: 3

    // Icons and their menus report themselves so the dock stays down while
    // they are in use (a menu is its own window, so it drops dock hover).
    property int hoverCount: 0
    property int holdCount: 0

    readonly property bool revealed: hotspot.hovered
        || hoverCount > 0
        || holdCount > 0
        || Apps.gridOpen

    property bool shown: false
    onRevealedChanged: {
        if (revealed) {
            hideTimer.stop();
            shown = true;
        } else {
            hideTimer.restart();
        }
    }

    Timer {
        id: hideTimer
        interval: 350
        onTriggered: if (!dock.revealed) dock.shown = false
    }

    mask: Region {
        x: 0
        y: dock.shown ? 0 : dock.height - dock.peek
        width: dock.width
        height: dock.shown ? dock.height : dock.peek
    }

    Item {
        id: hotspot
        anchors.fill: parent

        readonly property bool hovered: hoverHandler.hovered

        HoverHandler { id: hoverHandler }
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell:dock"

    readonly property var pinned: [
        { key: "launcher", isLauncher: true, glyph: "" },
        {
            key: "brave",
            icon: "file:///usr/share/pixmaps/brave-browser-nightly.png",
            exec: ["/usr/bin/brave-nightly"],
            match: /^brave-browser-nightly$/i
        },
        {
            key: "thunar",
            icon: Quickshell.iconPath("org.xfce.thunar"),
            exec: ["thunar"],
            match: /^thunar$/i
        },
        {
            key: "alacritty",
            icon: "file:///usr/share/pixmaps/Alacritty.svg",
            exec: ["alacritty"],
            match: /^alacritty$/i
        },
        {
            key: "vscode",
            icon: "file:///usr/share/pixmaps/vscode.png",
            exec: ["code"],
            match: /^code$/i
        },
        {
            key: "vesktop",
            icon: Quickshell.iconPath("vesktop"),
            exec: ["vesktop"],
            match: /^vesktop$/i
        }
    ]

    // An app minimised to the tray has no toplevel, so match it by its
    // StatusNotifierItem instead. Electron reports a generic id
    // ("chrome_status_icon_1"), so tooltip/title are checked as well.
    function findTrayItem(p) {
        const re = p.trayMatch || p.match;
        if (!re) return null;

        for (const item of SystemTray.items.values) {
            if (re.test(item.tooltipTitle || "") || re.test(item.title || "") || re.test(item.id || ""))
                return item;
        }
        return null;
    }

    function buildEntries() {
        const tops = ToplevelManager.toplevels.values;
        const used = new Array(tops.length).fill(false);
        const entries = [];

        for (const p of pinned) {
            if (p.isLauncher) {
                entries.push({
                    icon: null,
                    glyph: p.glyph,
                    running: false,
                    toplevels: [],
                    activate: () => Apps.gridOpen ? Apps.closeAll() : Apps.openGrid(dock.screen),
                    launchNew: () => Apps.gridOpen ? Apps.closeAll() : Apps.openGrid(dock.screen)
                });
                continue;
            }

            const matches = [];
            for (let i = 0; i < tops.length; i++) {
                if (!used[i] && p.match.test(tops[i].appId)) {
                    used[i] = true;
                    matches.push(tops[i]);
                }
            }

            // Only consult the tray when the app has no window of its own.
            const trayItem = matches.length > 0 ? null : findTrayItem(p);

            entries.push({
                icon: p.icon,
                glyph: null,
                running: matches.length > 0 || trayItem !== null,
                toplevels: matches,
                activate: matches.length > 0
                    ? (() => matches[0].activate())
                    : (trayItem !== null
                        ? (() => trayItem.activate())
                        : (() => Quickshell.execDetached(p.exec))),
                launchNew: () => Quickshell.execDetached(p.exec)
            });
        }

        const seenAppIds = new Set();
        for (let i = 0; i < tops.length; i++) {
            if (used[i]) continue;
            const appId = tops[i].appId;
            if (seenAppIds.has(appId)) continue;
            seenAppIds.add(appId);

            const group = [];
            for (let j = 0; j < tops.length; j++) {
                if (!used[j] && tops[j].appId === appId) group.push(tops[j]);
            }

            entries.push({
                icon: Quickshell.iconPath(appId, ""),
                glyph: null,
                running: true,
                toplevels: group,
                activate: (() => group[0].activate())
            });
        }

        return entries;
    }

    readonly property var entries: buildEntries()

    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: dock.shown ? 12 : -height
        height: 48
        radius: 16
        color: Colors.barBg
        width: row.implicitWidth + 16

        Behavior on anchors.bottomMargin {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 4

            Repeater {
                model: dock.entries

                DockIcon {
                    required property var modelData
                    appData: modelData
                    dockWindow: dock
                }
            }
        }
    }
}
