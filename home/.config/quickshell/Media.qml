pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// The MPRIS player the bar shows: the one playing, else the last one that played, else the first.
Singleton {
    id: root
    readonly property var players: Mpris.players.values
    property var lastPlaying: null
    readonly property var player: players.find(p => p.isPlaying)
                                  ?? (players.includes(lastPlaying) ? lastPlaying : null)
                                  ?? players[0] ?? null
    property var chosen: null   // picked by hand in the popup; wins while that player exists
    readonly property var active: chosen && players.includes(chosen) ? chosen : player

    onPlayerChanged: if (player?.isPlaying) lastPlaying = player

    // MPRIS doesn't push position updates; poll while something plays
    Timer {
        running: root.active?.isPlaying ?? false
        interval: 1000
        repeat: true
        onTriggered: root.active.positionChanged()
    }

    function time(s) {
        s = Math.max(0, Math.floor(s))
        const h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60, sec = String(s % 60).padStart(2, "0")
        return h ? `${h}:${String(m).padStart(2, "0")}:${sec}` : `${m}:${sec}`
    }
}
