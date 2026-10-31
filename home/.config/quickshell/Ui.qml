pragma Singleton
import QtQuick
import Quickshell

// Shared UI state: which bar popup is open (only one at a time), launcher, notification center.
Singleton {
    property string popup: ""          // "", "calendar", "power", "audio", "sysmon", "devices"
    property bool launcher: false
    property string launcherMode: "apps"   // "apps", "clipboard" or "emoji"
    property bool notifCenter: false
    property bool wallpapers: false
    property bool themeBrowser: false
    property bool quickSettings: false
    property bool overview: false
    property bool screenshot: false
    property bool cheatsheet: false
    property bool hyprSettings: false
    property bool session: false
    property string hyprSettingsTab: "look"   // look, binds, autostart, env
    property bool locked: false
    property bool keepAwake: false     // idle inhibitor, held by the bar
    property bool barKeys: false       // bar has keyboard focus (SUPER+ALT+B)
    property bool dockKeys: false      // dock has keyboard focus (SUPER+ALT+D)
    readonly property bool panelOpen: launcher || notifCenter || wallpapers || themeBrowser || quickSettings || overview || screenshot || cheatsheet || hyprSettings || session || locked
    onPanelOpenChanged: if (panelOpen) { barKeys = false; dockKeys = false }   // hand the keyboard to the panel
    onBarKeysChanged: if (barKeys) dockKeys = false
    onDockKeysChanged: if (dockKeys) barKeys = false

    function toggle(name) { popup = popup === name ? "" : name }
    function toggleLauncher(mode) {
        if (launcher && launcherMode === mode) launcher = false
        else { launcherMode = mode; launcher = true }
    }
    function closeAll() { popup = ""; launcher = false; notifCenter = false; wallpapers = false; themeBrowser = false; quickSettings = false; overview = false; screenshot = false; cheatsheet = false; hyprSettings = false; session = false }
}
