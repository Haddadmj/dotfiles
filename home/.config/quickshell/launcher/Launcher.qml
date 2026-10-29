import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.components

// Launcher dropping down from the launcher island, with three tabs:
//   Apps       SUPER+R / launcher island. Apps you launch often float to the top. Also:
//              math ("2*pi", "=5 usd to eur") via qalc · web search ("!g …", "!yt …", "!w …", "!gh …", "!aw …")
//              · shell commands (lock, reboot, overview, screenshot…) · right-click an app to pin it to the dock
//   Clipboard  SUPER+C. cliphist history; Enter copies, Shift+Delete removes the entry.
//   Emoji      SUPER+period. Enter copies the emoji.
// Type to search · ↑↓ to move · Tab or Ctrl+Tab switches tab · Enter · Esc or click outside to close.
PanelWindow {
    id: root
    readonly property bool open: Ui.launcher
    readonly property bool clip: Ui.launcherMode === "clipboard"
    readonly property bool emoji: Ui.launcherMode === "emoji"
    readonly property var modes: ["apps", "clipboard", "emoji"]
    readonly property string thumbDir: Quickshell.cachePath("cliphist")

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    WlrLayershell.namespace: "quickshell:launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: false

    onOpenChanged: {
        if (open) {
            hideTimer.stop()
            reset()
            visible = true
            search.forceActiveFocus()
        } else hideTimer.restart()
    }
    onClipChanged: if (open) reset()
    onEmojiChanged: if (open) reset()
    Timer { id: hideTimer; interval: Theme.anim; onTriggered: root.visible = false }

    function reset() {
        search.text = ""
        list.currentIndex = 0
        if (clip) clipList.running = true
    }

    component Tab: Rectangle {
        id: tab
        property string icon
        property string label
        property string mode
        readonly property bool on: Ui.launcherMode === mode
        Layout.fillWidth: true
        implicitHeight: 32
        radius: 8
        color: on ? Theme.primary : tm.containsMouse ? Theme.alpha(Theme.secondary, 0.9) : Theme.alpha(Theme.secondary, 0.4)
        Behavior on color { ColorAnimation { duration: 150 } }
        RowLayout {
            anchors.centerIn: parent
            spacing: 8
            T { text: tab.icon; font.pixelSize: 15; color: tab.on ? Theme.primaryText : Theme.fg }
            T { text: tab.label; color: tab.on ? Theme.primaryText : Theme.fg }
        }
        MouseArea {
            id: tm
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { Ui.launcherMode = tab.mode; search.forceActiveFocus() }
        }
    }

    // ── Apps ─────────────────────────────────────────
    FileView {
        id: usageFile
        path: Quickshell.statePath("launcher.json")
        onAdapterUpdated: writeAdapter()
        onLoadFailed: err => { if (err === FileViewError.FileNotFound) writeAdapter() }
        adapter: JsonAdapter { id: usage; property var counts: ({}) }
    }

    function score(app, q) {
        if (!q) return 1
        const name = app.name.toLowerCase()
        if (name.startsWith(q)) return 100
        if (name.split(/[\s\-_.]+/).some(w => w.startsWith(q))) return 80
        if (name.includes(q)) return 60
        const extra = `${app.genericName} ${app.keywords.join(" ")} ${app.id}`.toLowerCase()
        if (extra.includes(q)) return 40
        // letters in order, e.g. "vsc" → Visual Studio Code
        let i = 0
        for (const c of name) if (c === q[i]) i++
        return i === q.length ? 10 : 0
    }

    function appResults(q) {
        const counts = usage.counts
        return DesktopEntries.applications.values
            .filter(a => !a.noDisplay)
            .map(a => ({ app: a, score: score(a, q), used: counts[a.id] ?? 0 }))
            .filter(r => r.score > 0)
            .sort((a, b) => b.score - a.score || b.used - a.used || a.app.name.localeCompare(b.app.name))
            .map(r => ({
                app: r.app,
                title: r.app.name,
                subtitle: r.app.comment || r.app.genericName,
                icon: Quickshell.iconPath(r.app.icon, "application-x-executable"),
            }))
    }

    function launch(app) {
        const counts = Object.assign({}, usage.counts)
        counts[app.id] = (counts[app.id] ?? 0) + 1
        usage.counts = counts
        if (app.runInTerminal) Quickshell.execDetached(["ghostty", "-e", ...app.command])
        else app.execute()
        Ui.launcher = false
    }

    // ── Commands ─────────────────────────────────────
    readonly property var commands: [
        { name: "Lock", icon: Icons.lock, keywords: "lock screen", run: () => Quickshell.execDetached(["loginctl", "lock-session"]) },
        { name: "Log out", icon: Icons.logout, keywords: "logout exit session", run: () => Quickshell.execDetached(["sh", "-c", "hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"]) },
        { name: "Suspend", icon: Icons.suspend, keywords: "sleep suspend", run: () => Quickshell.execDetached(["systemctl", "suspend"]) },
        { name: "Reboot", icon: Icons.reboot, keywords: "restart reboot", run: () => Quickshell.execDetached(["systemctl", "reboot"]) },
        { name: "Shut down", icon: Icons.shutdown, keywords: "poweroff shutdown power off", run: () => Quickshell.execDetached(["systemctl", "poweroff"]) },
        { name: "Overview", icon: Icons.overview, keywords: "windows workspaces expose", run: () => Ui.overview = true },
        { name: "Quick settings", icon: Icons.tune, keywords: "wifi bluetooth settings", run: () => Ui.quickSettings = true },
        { name: "Change wallpaper", icon: Icons.image, keywords: "wallpaper theme background", run: () => Ui.wallpapers = true },
        { name: "Toggle light / dark", icon: Icons.moon, keywords: "dark light mode theme", run: () => Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/theme.sh", "toggle-mode"]) },
        { name: "Screenshot", icon: Icons.camera, keywords: "screenshot capture print", run: () => Ui.screenshot = true },
        { name: "Record screen", icon: Icons.record, keywords: "record video screencast", run: () => Recorder.toggle(false) },
        { name: "Hyprland settings", icon: Icons.settings, keywords: "hyprland settings gaps blur border rounding mouse sensitivity config", run: () => Ui.hyprSettings = true },
        { name: "Keybinds cheat sheet", icon: Icons.keyboard, keywords: "keybinds shortcuts cheatsheet help keys", run: () => Ui.cheatsheet = true },
        { name: "Emoji", icon: Icons.emoji, keywords: "emoji smiley", run: () => { Ui.launcherMode = "emoji"; Ui.launcher = true } },
    ]
    function commandResults(q) {
        if (!q) return []
        return commands
            .map(c => ({ c, score: c.name.toLowerCase().startsWith(q) ? 90 : (c.name + " " + c.keywords).toLowerCase().includes(q) ? 50 : 0 }))
            .filter(r => r.score > 0)
            .map(r => ({ run: r.c.run, title: r.c.name, subtitle: "Command", glyph: r.c.icon, score: r.score }))
    }

    // ── Web search ───────────────────────────────────
    readonly property var engines: ({
        g: { name: "Google", url: "https://www.google.com/search?q=" },
        yt: { name: "YouTube", url: "https://www.youtube.com/results?search_query=" },
        w: { name: "Wikipedia", url: "https://en.wikipedia.org/w/index.php?search=" },
        gh: { name: "GitHub", url: "https://github.com/search?q=" },
        aw: { name: "Arch Wiki", url: "https://wiki.archlinux.org/index.php?search=" },
        aur: { name: "AUR", url: "https://aur.archlinux.org/packages?K=" },
    })
    function webResult(raw) {
        const m = raw.match(/^!(\w+)\s+(.+)$/)
        if (!m || !engines[m[1]]) return null
        const e = engines[m[1]]
        return { run: () => Qt.openUrlExternally(e.url + encodeURIComponent(m[2])), title: m[2], subtitle: `Search ${e.name}`, glyph: Icons.web }
    }

    // ── Calculator (qalc) ────────────────────────────
    property string calcQuery: ""
    property string calcResult: ""
    function isMath(q) { return q.startsWith("=") || /^[\d\s.,()+\-*\/^%]*\d[\d\s.,()]*[+\-*\/^%][\s\d.,()+\-*\/^%a-z]*$/i.test(q) }
    Timer {
        id: calcDelay
        interval: 120
        onTriggered: { calc.running = false; calc.running = true }
    }
    Process {
        id: calc
        command: ["qalc", "-t", root.calcQuery.replace(/^=/, "")]
        stdout: StdioCollector { onStreamFinished: root.calcResult = text.trim() }
    }
    readonly property var calcItem: calcQuery && calcResult ? {
        run: () => Quickshell.execDetached(["wl-copy", root.calcResult]),
        title: calcResult, subtitle: `${calcQuery.replace(/^=/, "")}  ·  Enter copies`, glyph: Icons.calculator
    } : null

    // ── Emoji ────────────────────────────────────────
    property var emojis: []
    FileView {
        path: Quickshell.shellPath("data/emoji.json")
        onLoaded: root.emojis = JSON.parse(text())
    }
    function emojiResults(q) {
        const words = q.split(/\s+/).filter(w => w)
        return emojis
            .filter(e => words.every(w => e[1].includes(w)))
            .slice(0, 200)
            .map(e => ({ run: () => Quickshell.execDetached(["wl-copy", e[0]]), title: e[1], subtitle: "", emoji: e[0] }))
    }

    // ── Clipboard (cliphist) ─────────────────────────
    property var clips: []

    Process {
        id: clipList
        // list, and decode image entries to thumbnails we don't have yet
        command: ["sh", "-c", `
            dir="$1"; mkdir -p "$dir"
            list=$(cliphist list)
            printf '%s\\n' "$list" | grep -E '^[0-9]+\\s\\[\\[ binary data' | while IFS= read -r line; do
                id=\${line%%\t*}
                [ -s "$dir/$id" ] || printf '%s' "$line" | cliphist decode > "$dir/$id"
            done
            printf '%s\\n' "$list"`, "sh", root.thumbDir]
        stdout: StdioCollector {
            onStreamFinished: {
                root.clips = text.split("\n").filter(l => l).map(line => {
                    const tab = line.indexOf("\t")
                    const id = line.slice(0, tab)
                    const body = line.slice(tab + 1)
                    const img = body.match(/^\[\[ binary data (.+?) (\w+) (\d+x\d+) \]\]$/)
                    return { line, id, body, image: img ? `file://${root.thumbDir}/${id}` : "", info: img ? `${img[2]} · ${img[3]} · ${img[1]}` : "" }
                })
            }
        }
    }

    function clipResults(q) {
        return clips
            .filter(c => !q || (c.image ? c.info : c.body).toLowerCase().includes(q))
            .map(c => ({
                clip: c,
                title: c.image ? "Image" : c.body.replace(/\s+/g, " ").trim(),
                subtitle: c.image ? c.info : "",
                image: c.image,
            }))
    }

    function copy(c) {
        Quickshell.execDetached(["sh", "-c", `printf '%s' "$1" | cliphist decode | wl-copy`, "sh", c.line])
        Ui.launcher = false
    }
    function remove(c) {
        Quickshell.execDetached(["sh", "-c", `printf '%s' "$1" | cliphist delete; rm -f "$2"`, "sh", c.line, `${root.thumbDir}/${c.id}`])
        clips = clips.filter(x => x !== c)
    }

    // ── Shared ───────────────────────────────────────
    readonly property var results: {
        const raw = search.text.trim()
        const q = raw.toLowerCase()
        if (clip) return clipResults(q)
        if (emoji) return emojiResults(q)
        const web = webResult(raw)
        if (web) return [web]
        const calcs = calcItem && isMath(raw) ? [calcItem] : []
        const cmds = commandResults(q)
        const apps = appResults(q)
        // strong command matches go above apps, weak ones below
        return [...calcs, ...cmds.filter(c => c.score >= 90), ...apps, ...cmds.filter(c => c.score < 90)]
    }

    function activate(item) {
        if (!item) return
        if (item.app) launch(item.app)
        else if (item.clip) copy(item.clip)
        else { Ui.launcher = false; item.run() }
    }

    // click outside the box closes
    MouseArea {
        anchors.fill: parent
        onClicked: Ui.launcher = false
    }

    Rectangle {
        id: box
        x: 20
        y: Theme.gap + Theme.barHeight + 6
        width: 460
        height: 580
        radius: Theme.radius + 4
        color: Theme.popup
        border.width: 1
        border.color: Theme.alpha(Theme.primary, 0.35)
        opacity: root.open ? 1 : 0
        transform: Translate { y: root.open ? 0 : -12; Behavior on y { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } } }
        Behavior on opacity { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }

        MouseArea { anchors.fill: parent }   // swallow clicks so they don't close

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            // tabs
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Tab { icon: Icons.apps; label: "Apps"; mode: "apps" }
                Tab { icon: Icons.clipboard; label: "Clipboard"; mode: "clipboard" }
                Tab { icon: Icons.emoji; label: "Emoji"; mode: "emoji" }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 42
                radius: Theme.radius
                color: Theme.alpha(Theme.secondary, 0.6)
                border.width: 1
                border.color: search.activeFocus ? Theme.alpha(Theme.primary, 0.6) : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 10
                    T { text: Icons.search; color: Theme.primary; font.pixelSize: 16 }
                    TextInput {
                        id: search
                        Layout.fillWidth: true
                        color: Theme.fg
                        selectionColor: Theme.primary
                        selectedTextColor: Theme.primaryText
                        font.family: Theme.font
                        font.pixelSize: 14
                        clip: true
                        onTextChanged: {
                            list.currentIndex = 0
                            const t = text.trim()
                            if (!root.clip && !root.emoji && root.isMath(t)) { root.calcQuery = t; calcDelay.restart() }
                            else { root.calcQuery = ""; root.calcResult = "" }
                        }

                        T {
                            visible: !search.text
                            text: root.clip ? "Search clipboard…" : root.emoji ? "Search emoji…" : "Search apps, =math, !g web…"
                            color: Theme.alpha(Theme.fg, 0.4)
                            font.pixelSize: 14
                            font.weight: Font.Normal
                        }

                        function switchTab(step) { Ui.launcherMode = root.modes[(root.modes.indexOf(Ui.launcherMode) + step + 3) % 3] }

                        Keys.onPressed: e => {
                            if (e.key === Qt.Key_Escape) Ui.launcher = false
                            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.activate(root.results[list.currentIndex])
                            else if (e.key === Qt.Key_Up) list.decrementCurrentIndex()
                            else if (e.key === Qt.Key_Down) list.incrementCurrentIndex()
                            else if (e.key === Qt.Key_Tab) switchTab(1)
                            else if (e.key === Qt.Key_Backtab) switchTab(-1)
                            else if (e.key === Qt.Key_Delete && (e.modifiers & Qt.ShiftModifier) && root.clip) {
                                const item = root.results[list.currentIndex]
                                if (item) root.remove(item.clip)
                            } else return
                            e.accepted = true
                        }
                    }
                    T { text: root.results.length; color: Theme.fgDim; font.pixelSize: 11 }
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                model: ScriptModel { values: root.results }
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 120
                highlightResizeDuration: 0
                highlight: Rectangle { radius: 8; color: Theme.primary }
                WheelScroll { view: list }

                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool current: ListView.isCurrentItem
                    width: ListView.view.width
                    height: modelData.image ? 72 : 46

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 28   // clear the pinned dot
                        spacing: 12

                        T {
                            visible: row.modelData.glyph !== undefined || row.modelData.emoji !== undefined
                            Layout.preferredWidth: 28
                            horizontalAlignment: Text.AlignHCenter
                            text: row.modelData.emoji ?? row.modelData.glyph ?? ""
                            font.family: row.modelData.emoji ? "Noto Color Emoji" : Theme.font
                            font.pixelSize: row.modelData.emoji ? 22 : 20
                            color: row.current ? Theme.primaryText : Theme.primary
                        }
                        IconImage {
                            visible: row.modelData.app !== undefined
                            implicitSize: 28
                            source: row.modelData.icon ?? ""
                        }
                        ClippingRectangle {
                            visible: row.modelData.image !== undefined && row.modelData.image !== ""
                            implicitWidth: 88
                            implicitHeight: 60
                            radius: 6
                            color: Theme.alpha(Theme.secondary, 0.8)
                            Image {
                                anchors.fill: parent
                                source: row.modelData.image ?? ""
                                fillMode: Image.PreserveAspectCrop
                                sourceSize: Qt.size(176, 120)
                                asynchronous: true
                                cache: false
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            T {
                                Layout.fillWidth: true
                                text: row.modelData.title
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                font.weight: row.modelData.clip ? Font.Normal : Font.DemiBold
                                color: row.current ? Theme.primaryText : Theme.fg
                            }
                            T {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: row.modelData.subtitle ?? ""
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                font.pixelSize: 11
                                font.weight: Font.Normal
                                color: row.current ? Theme.alpha(Theme.primaryText, 0.8) : Theme.fgDim
                            }
                        }
                    }

                    // in the dock
                    Rectangle {
                        visible: row.modelData.app !== undefined && Dock.isPinned(row.modelData.app.id)
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: 6
                        height: 6
                        radius: 3
                        color: row.current ? Theme.primaryText : Theme.primary
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onEntered: list.currentIndex = row.index
                        onClicked: e => {
                            if (e.button === Qt.RightButton) { if (row.modelData.app) Dock.togglePin(row.modelData.app.id) }
                            else if (e.button === Qt.MiddleButton && row.modelData.clip) root.remove(row.modelData.clip)
                            else root.activate(row.modelData)
                        }
                    }
                }

                T {
                    anchors.centerIn: parent
                    visible: root.results.length === 0
                    text: root.clip ? (root.clips.length ? "No matches" : "Clipboard history is empty") : root.emoji ? "No emoji found" : "No apps found"
                    color: Theme.alpha(Theme.fg, 0.4)
                }
            }

            T {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.clip ? "Enter copy · Shift+Del / middle-click remove · Tab emoji"
                    : root.emoji ? "Enter copy · Tab apps"
                    : "Enter launch · right-click pin to dock · =2+2 math · !g !w web · Tab clipboard"
                color: Theme.alpha(Theme.fg, 0.4)
                font.pixelSize: 11
                font.weight: Font.Normal
            }
        }
    }
}
