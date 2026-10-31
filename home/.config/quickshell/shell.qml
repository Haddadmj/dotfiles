//@ pragma UseQApplication
// Quickshell desktop shell: bar, launcher, notifications, OSD. Colors from matugen (colors.json).
// Control from Hyprland binds:  qs ipc call launcher toggle | cheatsheet toggle | hyprsettings toggle | launcher clipboard | wallpapers toggle | themes toggle | dock toggle | dock apps | notifications toggle | notifications dnd | dock focus | bar focus | bar toggle power | session toggle
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs
import qs.bar
import qs.desktop
import qs.dock
import qs.launcher
import qs.lock
import qs.notifications
import qs.osd
import qs.panels

ShellRoot {
    Variants {
        model: Quickshell.screens
        Bar {}
    }
    Variants {
        model: Quickshell.screens
        DesktopWidgets {}
    }
    Variants {
        model: Quickshell.screens
        DockPanel {}
    }

    Launcher {}
    WallpaperPicker {}
    ThemeBrowser {}
    QuickSettings {}
    Overview {}
    ScreenshotMenu {}
    SessionMenu {}
    Cheatsheet {}
    HyprSettings {}
    Lock {}
    NotificationPopups {}
    NotificationCenter {}
    VolumeOsd {}
    InfoOsd {}
    ChatOverlay { id: chat }

    IpcHandler {
        target: "launcher"
        function toggle(): void { Ui.toggleLauncher("apps") }
        function clipboard(): void { Ui.toggleLauncher("clipboard") }
        function emoji(): void { Ui.toggleLauncher("emoji") }
    }
    IpcHandler {
        target: "quicksettings"
        function toggle(): void { Ui.quickSettings = !Ui.quickSettings }
    }
    IpcHandler {
        target: "overview"
        function toggle(): void { Ui.overview = !Ui.overview }
    }
    IpcHandler {
        target: "screenshot"
        function toggle(): void { Ui.screenshot = !Ui.screenshot }
    }
    IpcHandler {
        target: "cheatsheet"
        function toggle(): void { Ui.cheatsheet = !Ui.cheatsheet }
    }
    IpcHandler {
        target: "hyprsettings"
        function toggle(): void { Ui.hyprSettings = !Ui.hyprSettings }
        // look · binds · autostart · env
        function open(tab: string): void { Ui.hyprSettingsTab = tab; Ui.hyprSettings = true }
    }
    IpcHandler {
        target: "recorder"
        function screen(): void { Recorder.toggle(false) }
        function region(): void { Recorder.toggle(true) }
        function stop(): void { Recorder.stop() }
    }
    IpcHandler {
        target: "session"
        function toggle(): void { Ui.session = !Ui.session }
    }
    IpcHandler {
        target: "chat"
        function toggle(): void { chat.hidden = !chat.hidden }
    }
    IpcHandler {
        target: "lock"
        function lock(): void { Ui.closeAll(); Ui.locked = true }
    }
    IpcHandler {
        target: "wallpapers"
        function toggle(): void { Ui.wallpapers = !Ui.wallpapers }
    }
    IpcHandler {
        target: "themes"
        function toggle(): void { Ui.themeBrowser = !Ui.themeBrowser }
    }
    IpcHandler {
        target: "notifications"
        function toggle(): void { Ui.notifCenter = !Ui.notifCenter }
        function dnd(): void { Notifs.dnd = !Notifs.dnd }
        function clear(): void { Notifs.clear() }
    }
    IpcHandler {
        target: "dock"
        // show/hide the dock (SUPER+D) · open the Applications folder on the focused screen
        function toggle(): void { Dock.toggle() }
        function apps(): void { Ui.toggle("dock-apps:" + (Hyprland.focusedMonitor?.name ?? Quickshell.screens[0].name)) }
        // keyboard navigation (SUPER+ALT+D): ←/→ move · Enter open · Menu / Shift+F10 menu · Esc leave
        function focus(): void { Ui.dockKeys = !Ui.dockKeys }
    }
    IpcHandler {
        target: "bar"
        // calendar · audio · power
        function toggle(popup: string): void { Ui.toggle(popup) }
        // keyboard navigation: ←/→ Tab move · Enter open · Esc leave
        function focus(): void { Ui.barKeys = !Ui.barKeys }
    }
}
