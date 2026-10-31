import QtQuick
import QtWebSockets
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs

// Transparent, click-through Twitch chat on top of everything while OBS is open
// (SUPER+ALT+C = `qs ipc call chat toggle` hides/shows it until OBS closes).
// Reads chat anonymously over Twitch IRC; hidden from screen share by a layer rule so it never ends up on stream.
// Settings live in ~/.config/quickshell/chat.json (watched, applies on save): fadeSeconds (0 = never fade), maxLines,
// font (English), arabicFont, fontSize.
PanelWindow {
    id: root
    property string channel: "nightgamerksa"
    readonly property bool obsOpen: ToplevelManager.toplevels.values.some(t => t.appId === "com.obsproject.Studio" || t.appId === "obs")   // "obs" = under XWayland (QT_QPA_PLATFORM=xcb)
    property bool hidden: false
    readonly property bool shown: obsOpen && !hidden
    onObsOpenChanged: hidden = false
    readonly property int maxLines: Math.max(1, cfg.maxLines)
    readonly property int fadeMs: Math.max(0, cfg.fadeSeconds) * 1000
    property double now: Date.now()

    FileView {
        path: Quickshell.shellPath("chat.json")
        watchChanges: true
        onFileChanged: reload()
        onLoadFailed: err => { if (err === FileViewError.FileNotFound) writeAdapter() }
        adapter: JsonAdapter {
            id: cfg
            property real fadeSeconds: 30
            property int maxLines: 14
            property string font: "Noto Sans"
            property string arabicFont: "Noto Sans Arabic"
            property int fontSize: 14
        }
    }

    // drops messages older than fadeMs; delegates fade out over their last second
    Timer {
        interval: 250
        repeat: true
        running: root.shown && root.fadeMs > 0 && lines.count > 0
        onTriggered: {
            root.now = Date.now()
            while (lines.count && root.now - lines.get(0).time > root.fadeMs) lines.remove(0)
        }
    }

    WlrLayershell.namespace: "quickshell:chat"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors { right: true; top: true }
    margins { right: 16; top: 80 }
    exclusiveZone: 0
    implicitWidth: 380
    implicitHeight: 520
    color: "transparent"
    visible: shown
    mask: Region {}   // clicks pass through

    ListModel { id: lines }

    // Qt ignores font fallback lists and picks its own Arabic font, so Arabic runs get an explicit span
    readonly property var arabicRun: /[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]+(?:[\s\d.,!?]+[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]+)*/g
    function arabic(s) { return s.replace(arabicRun, m => `<span style="font-family:'${cfg.arabicFont}'">${m}</span>`) }

    function esc(s) { return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;") }

    // @tags :nick!nick@nick.tmi.twitch.tv PRIVMSG #chan :text
    function handle(line) {
        if (line.startsWith("PING")) { ws.sendTextMessage("PONG :tmi.twitch.tv"); return }
        const room = line.match(/^@\S*\broom-id=(\d+)/)   // on ROOMSTATE (sent on join) and every message
        if (room) roomId = room[1]
        const m = line.match(/^@(\S+) :(\w+)!\S+ PRIVMSG #\S+ :(.*)$/)
        if (!m) return
        const tags = {}
        for (const kv of m[1].split(";")) { const i = kv.indexOf("="); tags[kv.slice(0, i)] = kv.slice(i + 1) }
        let text = m[3]
        if (text.startsWith("\u0001ACTION ")) text = text.slice(8, -1)   // /me
        queue.push({ name: tags["display-name"] || m[2], tint: tags["color"] || String(Theme.fgDim), parts: split(text, tags["emotes"]) })
        pump()
    }

    // Emotes. Images don't load over the network here, so each one is curl'ed once into emoteDir.
    readonly property string emoteDir: Quickshell.cachePath("emotes")
    property var cached: ({})   // file name → true (in emoteDir) / false (download failed)
    property var queue: []      // messages waiting for their emote downloads, kept in arrival order

    // BetterTTV / FFZ / 7TV have no IRC tag: plain words are looked up in these code → { file, url } maps
    property var globalEmotes: ({})
    property var channelEmotes: ({})   // wins over global
    property string roomId: ""
    onRoomIdChanged: loadEmotes(true)
    Component.onCompleted: loadEmotes(false)

    function getJson(url, cb) {
        const x = new XMLHttpRequest()
        x.onreadystatechange = () => {
            if (x.readyState === XMLHttpRequest.DONE && x.status === 200) { try { cb(JSON.parse(x.responseText)) } catch (e) {} }
        }
        x.open("GET", url)
        x.send()
    }
    function loadEmotes(channel) {
        const add = list => {
            const e = Object.assign({}, channel ? channelEmotes : globalEmotes)
            for (const [code, file, url] of list) if (/^https:/.test(url || "")) e[code] = { file: file, url: url }
            if (channel) channelEmotes = e
            else globalEmotes = e
        }
        const bttv = l => l.map(x => [x.code, "bttv_" + x.id, `https://cdn.betterttv.net/emote/${x.id}/2x`])
        const ffz = l => l.map(x => [x.code, "ffz_" + x.id, x.images["2x"] || x.images["1x"]])
        const stv = l => l.map(x => [x.name, "7tv_" + x.id, `https://cdn.7tv.app/emote/${x.id}/2x.webp`])
        const api = "https://api.betterttv.net/3/cached"
        if (channel) {
            getJson(`${api}/users/twitch/${roomId}`, j => add(bttv([...(j.channelEmotes || []), ...(j.sharedEmotes || [])])))
            getJson(`${api}/frankerfacez/users/twitch/${roomId}`, j => add(ffz(j)))
            getJson(`https://7tv.io/v3/users/twitch/${roomId}`, j => add(stv(j.emote_set?.emotes || [])))
        } else {
            getJson(`${api}/emotes/global`, j => add(bttv(j)))
            getJson(`${api}/frankerfacez/emotes/global`, j => add(ffz(j)))
            getJson("https://7tv.io/v3/emote-sets/global", j => add(stv(j.emotes || [])))
        }
    }
    function lookup(word) {
        const has = (o, k) => Object.prototype.hasOwnProperty.call(o, k)
        return has(channelEmotes, word) ? channelEmotes[word] : has(globalEmotes, word) ? globalEmotes[word] : null
    }
    function words(plain, parts) {
        for (const w of plain.split(/(\s+)/)) {
            const e = lookup(w)
            parts.push(e ? { file: e.file, url: e.url, text: w } : { text: w })
        }
    }

    // Twitch's emotes tag "id:0-4,6-10/id2:12-15" (code point ranges) → [{ text }, { file, url, text }, …]
    function split(text, tag) {
        const at = {}
        for (const e of (tag || "").split("/")) {
            const [id, spans] = e.split(":")
            if (!/^[\w-]+$/.test(id || "") || !spans) continue
            for (const range of spans.split(",")) { const [a, b] = range.split("-").map(Number); at[a] = { id: id, end: b } }
        }
        const cps = Array.from(text), parts = []
        let plain = ""
        for (let i = 0; i < cps.length; i++) {
            if (!at[i]) { plain += cps[i]; continue }
            words(plain, parts)
            plain = ""
            const id = at[i].id
            parts.push({ file: "tw_" + id, url: `https://static-cdn.jtvnw.net/emoticons/v2/${id}/default/dark/2.0`, text: cps.slice(i, at[i].end + 1).join("") })
            i = at[i].end
        }
        words(plain, parts)
        return parts
    }

    function pump() {
        while (queue.length && !fetch.busy) {
            const need = queue[0].parts.filter(p => p.file && !(p.file in cached))
            if (need.length) {
                fetch.running = false
                fetch.need = need.filter((p, i) => need.findIndex(q => q.file === p.file) === i)
                fetch.busy = true
                fetch.running = true
                return   // continues when the download finishes
            }
            const m = queue.shift()
            root.now = Date.now()
            const html = m.parts.map(p => p.file && cached[p.file]
                ? `<img src="file://${emoteDir}/${p.file}" height="${cfg.fontSize * 2}" align="middle">` : esc(p.text)).join("")
            lines.append({ time: root.now, name: m.name, tint: m.tint, text: html })
            while (lines.count > root.maxLines) lines.remove(0)
        }
    }

    Process {
        id: fetch
        property var need: []
        property bool busy: false
        // args: dir, then file url pairs
        command: ["sh", "-c", 'mkdir -p "$1" && cd "$1" && shift && while [ $# -gt 1 ]; do [ -s "$1" ] || curl -sfL --max-time 5 -o "$1" "$2"; shift 2; done; ls',
                  "sh", root.emoteDir, ...need.reduce((a, p) => a.concat([p.file, p.url]), [])]
        stdout: StdioCollector {
            onStreamFinished: {
                const c = Object.assign({}, root.cached)
                for (const p of fetch.need) c[p.file] = false
                for (const f of text.split("\n")) if (f) c[f] = true
                root.cached = c
                fetch.busy = false
                root.pump()
            }
        }
    }

    WebSocket {
        id: ws
        url: "wss://irc-ws.chat.twitch.tv:443"
        active: root.shown
        onStatusChanged: status => {
            if (status === WebSocket.Open) {
                sendTextMessage("CAP REQ :twitch.tv/tags")
                sendTextMessage("PASS SCHMOOPIIE")
                sendTextMessage("NICK justinfan" + Math.floor(10000 + Math.random() * 80000))
                sendTextMessage("JOIN #" + root.channel)
            } else if (status === WebSocket.Error || status === WebSocket.Closed) {
                if (root.shown) retry.restart()
            }
        }
        onTextMessageReceived: message => message.split("\r\n").forEach(root.handle)
    }
    Timer { id: retry; interval: 5000; onTriggered: { ws.active = false; ws.active = root.shown } }

    Column {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        spacing: 4
        Repeater {
            model: lines
            Rectangle {
                required property string name
                required property string tint
                required property string text
                required property double time
                width: parent.width
                opacity: root.fadeMs > 0 ? Math.min(1, (root.fadeMs - (root.now - time)) / 1000) : 1
                height: msg.implicitHeight + 10
                radius: 8
                color: Theme.alpha(Theme.bg, 0.45)
                Text {
                    id: msg
                    anchors { fill: parent; margins: 5; leftMargin: 8; rightMargin: 8 }
                    wrapMode: Text.Wrap
                    textFormat: Text.RichText   // StyledText has no per-span font-family
                    font.family: cfg.font
                    font.pixelSize: cfg.fontSize
                    color: Theme.fg
                    style: Text.Outline
                    styleColor: "#80000000"
                    text: `<b><font color="${parent.tint}">${root.arabic(parent.name)}</font></b>: ${root.arabic(parent.text)}`
                }
            }
        }
    }
}
