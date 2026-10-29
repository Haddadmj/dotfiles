pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Dock state shared by every screen's dock and the launcher (right-click an app there to pin it).
// Saved to <state>/dock.json: pinned desktop entry ids, folders, hide mode, magnification.
// A pinned id starting with "folder:" is a folder; its name and apps live in `folders`.
Singleton {
    id: root
    readonly property var pinned: cfg.pinned
    readonly property var folders: cfg.folders        // [{ id: "folder:…", name, apps: [entry ids] }]
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
            property var folders: []
            property string hideMode: "dodge"
            property bool magnify: true
        }
    }

    function setHideMode(m) { cfg.hideMode = m }
    function setMagnify(on) { cfg.magnify = on }

    // "pinned" covers apps on the dock itself and apps inside a folder on it
    function isFolder(id) { return id.startsWith("folder:") }
    function folder(fid) { return cfg.folders.find(f => f.id === fid) ?? null }
    function folderOf(id) { return cfg.folders.find(f => f.apps.includes(id)) ?? null }
    function isPinned(id) { return cfg.pinned.includes(id) || !!folderOf(id) }
    function pin(id) { if (id && !isPinned(id)) cfg.pinned = [...cfg.pinned, id] }
    function unpin(id) {
        cfg.pinned = cfg.pinned.filter(p => p !== id)
        cfg.folders = isFolder(id) ? cfg.folders.filter(f => f.id !== id) : stripped(id)
    }
    function togglePin(id) { isPinned(id) ? unpin(id) : pin(id) }
    // put an app (taking it out of any folder) or a folder at position `to` on the dock
    function movePinned(id, to) {
        const list = cfg.pinned.filter(p => p !== id)
        list.splice(Math.max(0, Math.min(to, list.length)), 0, id)
        if (!isFolder(id) && folderOf(id)) cfg.folders = stripped(id)
        cfg.pinned = list
    }
    function stripped(id) { return cfg.folders.map(f => f.apps.includes(id) ? Object.assign({}, f, { apps: f.apps.filter(a => a !== id) }) : f) }

    // ── folders ──────────────────────────────────────
    // a name from what the apps have in common (Emulator → "Emulators"), else "Folder"
    readonly property var categoryNames: [
        ["Emulator", "Emulators"], ["Game", "Games"], ["Development", "Development"], ["Graphics", "Graphics"],
        ["AudioVideo", "Media"], ["Audio", "Media"], ["Video", "Media"], ["Office", "Office"],
        ["Network", "Internet"], ["Education", "Education"], ["Science", "Science"],
        ["Settings", "Settings"], ["System", "System"], ["Utility", "Utilities"],
    ]
    function guessName(apps) {
        const cats = apps.map(id => DesktopEntries.byId(id)?.categories ?? [])
        const hit = categoryNames.find(([c]) => cats.length && cats.every(list => list.includes(c)))
        return hit ? hit[1] : "Folder"
    }
    // new folder at position `at` (default: the end); the apps leave wherever they were. Returns its id.
    function createFolder(apps, at, name) {
        const fid = "folder:" + Date.now().toString(36)
        let list = cfg.pinned.filter(p => !apps.includes(p))
        const k = at === undefined ? list.length : Math.max(0, Math.min(at, list.length))
        list.splice(k, 0, fid)
        let fs = cfg.folders
        for (const a of apps) fs = fs.map(f => f.apps.includes(a) ? Object.assign({}, f, { apps: f.apps.filter(x => x !== a) }) : f)
        cfg.folders = [...fs, { id: fid, name: name ?? guessName(apps), apps: [...apps] }]
        cfg.pinned = list
        return fid
    }
    function renameFolder(fid, name) {
        name = name.trim()
        if (name) cfg.folders = cfg.folders.map(f => f.id === fid ? Object.assign({}, f, { name }) : f)
    }
    function addToFolder(fid, id) {
        if (!folder(fid) || folder(fid).apps.includes(id)) return
        cfg.pinned = cfg.pinned.filter(p => p !== id)
        cfg.folders = stripped(id).map(f => f.id === fid ? Object.assign({}, f, { apps: Array.from(f.apps).concat(id) }) : f)
    }
    function removeFromFolder(fid, id) { cfg.folders = cfg.folders.map(f => f.id === fid ? Object.assign({}, f, { apps: f.apps.filter(a => a !== id) }) : f) }
    function toggleInFolder(fid, id) { folder(fid)?.apps.includes(id) ? removeFromFolder(fid, id) : addToFolder(fid, id) }
    // drop `id` onto `target` on the dock: join its folder, or make a new folder of the two. Returns the folder id.
    function combine(id, target) {
        if (isFolder(target)) { addToFolder(target, id); return target }
        return createFolder([target, id], cfg.pinned.indexOf(target))
    }
    // dissolve a folder, its apps taking its place on the dock
    function ungroup(fid) {
        const f = folder(fid)
        if (!f) return
        const list = cfg.pinned.filter(p => !f.apps.includes(p))
        list.splice(list.indexOf(fid), 1, ...f.apps)
        cfg.folders = cfg.folders.filter(x => x.id !== fid)
        cfg.pinned = list
    }

    function appIdOf(t) { return t.wayland?.appId ?? t.lastIpcObject?.class ?? "" }

    // a pinned app this window belongs to, by .desktop id or StartupWMClass (several .desktop files can share a class)
    function pinnedFor(appId) {
        const a = appId.toLowerCase()
        return cfg.folders.reduce((all, f) => all.concat(Array.from(f.apps)), Array.from(cfg.pinned)).find(id => {
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

    // dock order: pinned apps and folders, then running apps that aren't pinned (apps in a folder show up here while open)
    // a folder item has `folder` and `apps` (app items); its `windows` are all of theirs
    function appItem(id, pinned) { return { id, entry: DesktopEntries.byId(id), pinned, windows: running[id] ?? [] } }
    readonly property var items: {
        DesktopEntries.applications.values
        const r = running
        const list = cfg.pinned
            .map(id => {
                if (!isFolder(id)) return appItem(id, true)
                const f = folder(id)
                if (!f) return null
                const apps = f.apps.map(a => appItem(a, true)).filter(a => a.entry)
                return { id, folder: f, apps, pinned: true, windows: apps.reduce((all, a) => all.concat(a.windows), []) }
            })
            .filter(i => i && (i.entry || i.folder))
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
