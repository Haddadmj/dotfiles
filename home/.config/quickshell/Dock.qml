pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Dock state shared by every screen's dock and the launcher (right-click an app there to pin it).
// Saved to <state>/dock.json: pinned desktop entry ids, hide mode, magnification.
Singleton {
    id: root
    readonly property var pinned: cfg.pinned
    // "dodge" (hides while a window covers it) · "always" (shows at the screen edge) · "never"
    // The dock never reserves space, so windows keep their full size.
    readonly property string hideMode: ["dodge", "always", "never"].includes(cfg.hideMode) ? cfg.hideMode : "dodge"
    readonly property bool magnify: cfg.magnify
    property string override: ""                      // "" · "show" · "hide": SUPER+D (qs ipc call dock toggle)
    signal toggleRequested()                          // handled by the dock on the focused screen
    function toggle() { toggleRequested() }
    property string launching: ""                     // entry id that bounces until its window shows up

    FileView {
        path: Quickshell.statePath("dock.json")
        onAdapterUpdated: writeAdapter()
        onLoadFailed: err => { if (err === FileViewError.FileNotFound) writeAdapter() }
        adapter: JsonAdapter {
            id: cfg
            property var pinned: ["org.kde.dolphin", "com.mitchellh.ghostty", "brave-origin-nightly", "code-oss", "obsidian"]
            property string hideMode: "dodge"
            property bool magnify: true
        }
    }

    function setHideMode(m) { cfg.hideMode = m }
    function setMagnify(on) { cfg.magnify = on }

    function isPinned(id) { return cfg.pinned.includes(id) }
    function pin(id) { if (id && !isPinned(id)) cfg.pinned = [...cfg.pinned, id] }
    function unpin(id) { cfg.pinned = cfg.pinned.filter(p => p !== id) }
    function togglePin(id) { isPinned(id) ? unpin(id) : pin(id) }
    function movePinned(id, to) {
        const list = cfg.pinned.filter(p => p !== id)
        list.splice(Math.max(0, Math.min(to, list.length)), 0, id)
        cfg.pinned = list
    }

    function appIdOf(t) { return t.wayland?.appId ?? t.lastIpcObject?.class ?? "" }

    // a pinned app this window belongs to, by .desktop id or StartupWMClass (several .desktop files can share a class)
    function pinnedFor(appId) {
        const a = appId.toLowerCase()
        return cfg.pinned.find(id => {
            const e = DesktopEntries.byId(id)
            return id.toLowerCase() === a || (e?.startupClass ?? "").toLowerCase() === a
        })
    }

    // open windows grouped by desktop entry id (or the raw app id when no .desktop file matches)
    readonly property var running: {
        DesktopEntries.applications.values   // re-group once desktop entries are scanned
        const out = {}
        for (const t of Hyprland.toplevels.values) {
            const appId = appIdOf(t)
            if (!appId) continue
            const key = pinnedFor(appId) ?? DesktopEntries.heuristicLookup(appId)?.id ?? appId
            if (!out[key]) out[key] = []
            out[key].push(t)
        }
        return out
    }

    // dock order: pinned apps, then running apps that aren't pinned
    readonly property var items: {
        DesktopEntries.applications.values
        const r = running
        const list = cfg.pinned
            .map(id => ({ id, entry: DesktopEntries.byId(id), pinned: true, windows: r[id] ?? [] }))
            .filter(i => i.entry)
        for (const key in r)
            if (!cfg.pinned.includes(key)) list.push({ id: key, entry: DesktopEntries.byId(key), pinned: false, windows: r[key] })
        return list
    }

    // window positions (lastIpcObject) aren't pushed by Hyprland; re-read them when windows change
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (["openwindow", "closewindow", "movewindowv2", "changefloatingmode", "fullscreen", "workspacev2", "activewindowv2"].includes(event.name))
                refresh.restart()
        }
    }
    Timer { id: refresh; interval: 120; onTriggered: Hyprland.refreshToplevels() }
    function refreshWindows() { refresh.restart() }

    onRunningChanged: if (launching && running[launching]) launching = ""
    Timer { id: launchTimeout; interval: 6000; onTriggered: root.launching = "" }

    function launch(id) {
        const e = DesktopEntries.byId(id)
        if (!e) return
        if (e.runInTerminal) Quickshell.execDetached(["ghostty", "-e", ...e.command])
        else e.execute()
        if (!running[id]) { launching = id; launchTimeout.restart() }
    }

    // where an icon may live, best first (used by dock/AppIcon.qml)
    readonly property var iconDirs: {
        const home = Quickshell.env("HOME")
        const dirs = []
        for (const base of ["/usr/share/icons/hicolor", home + "/.local/share/icons/hicolor"])
            for (const size of ["scalable", "512x512", "256x256", "128x128", "96x96", "64x64", "48x48"])
                dirs.push(`${base}/${size}/apps`)
        return [...dirs, "/usr/share/icons/breeze/places/96", "/usr/share/icons/breeze/apps/48", "/usr/share/pixmaps"]
    }
    function iconSources(name) {
        if (!name) return [Quickshell.iconPath("application-x-executable")]
        if (name.startsWith("/")) return ["file://" + name]
        const themed = Quickshell.iconPath(name, true)
        const files = []
        for (const d of iconDirs) files.push(`file://${d}/${name}.svg`, `file://${d}/${name}.png`)
        return [...(themed ? [themed] : []), ...files, Quickshell.iconPath("application-x-executable")]
    }

    function addr(t) { const a = t.address; return a.startsWith("0x") ? a : "0x" + a }
    function focusWindow(t) { Hyprland.dispatch(`hl.dsp.focus({ window = "address:${addr(t)}" })`) }
    function closeWindow(t) { Hyprland.dispatch(`hl.dsp.window.close({ window = "address:${addr(t)}" })`) }

    // click: launch if closed, otherwise focus its window (cycling when it has several)
    function activate(item) {
        const w = item.windows
        if (!w.length) return launch(item.id)
        const i = w.findIndex(t => t.activated)
        focusWindow(w[(i + 1) % w.length])
    }
}
