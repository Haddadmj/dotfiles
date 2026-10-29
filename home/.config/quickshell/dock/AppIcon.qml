import QtQuick
import Quickshell
import qs

// App icon by name (or absolute path). Quickshell's theme lookup misses some icons that do exist
// (e.g. hicolor 512px-only apps, breeze "places"), so on a load error this walks the usual files on disk.
// The source size is fixed so the dock's magnification scales the texture instead of reloading it.
Image {
    id: root
    property string icon: ""
    property int attempt: 0
    readonly property var candidates: Dock.iconSources(icon)

    source: candidates[Math.min(attempt, candidates.length - 1)] ?? ""
    sourceSize: Qt.size(128, 128)
    fillMode: Image.PreserveAspectFit
    smooth: true
    mipmap: true
    onCandidatesChanged: attempt = 0
    // deferred: stepping `source` from inside its own status change is a binding loop
    onStatusChanged: if (status === Image.Error) Qt.callLater(next)
    function next() { if (status === Image.Error && attempt < candidates.length - 1) attempt++ }
}
