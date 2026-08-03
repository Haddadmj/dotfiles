import Quickshell
import Quickshell.Io

ShellRoot {
    // Lets the launchers be opened from outside the shell, e.g. from a keybind:
    //   qs ipc call launcher grid
    //   qs ipc call launcher menu
    IpcHandler {
        target: "launcher"

        function grid(): void {
            if (Apps.gridOpen) Apps.closeAll();
            else Apps.openGrid(Quickshell.screens[0]);
        }

        function menu(): void {
            if (Apps.menuOpen) Apps.closeAll();
            else Apps.openMenu(Quickshell.screens[0]);
        }

        function close(): void {
            Apps.closeAll();
        }
    }

    // Alt-tab overlay:  qs ipc call windows toggle
    //
    // Not named `show`: the qs CLI swallows that word as its own `ipc show`
    // subcommand, so `qs ipc call windows show` prints this handler's interface
    // and never calls anything. Every other name behaves normally.
    IpcHandler {
        target: "windows"

        function toggle(): void {
            if (Switcher.open) Switcher.close();
            else Switcher.show(Quickshell.screens[0]);
        }

        function close(): void {
            Switcher.close();
        }
    }

    // ~/.local/bin/game-mode calls `qs ipc call gamemode sync` after it flips,
    // so the bar indicator follows the keybind and gamemoded's Steam hooks
    // without polling for it.
    IpcHandler {
        target: "gamemode"

        function sync(): void {
            GameMode.sync();
        }

        function toggle(): void {
            GameMode.toggle();
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: Bar {}
    }

    Variants {
        model: Quickshell.screens

        delegate: Dock {}
    }

    // GNOME-style grid (dock launcher)
    Variants {
        model: Quickshell.screens

        delegate: AppGrid {}
    }

    // Windows-style start menu (bar launcher)
    Variants {
        model: Quickshell.screens

        delegate: StartMenu {}
    }

    Variants {
        model: Quickshell.screens

        delegate: WindowSwitcher {}
    }

    // Month view under the bar clock
    Variants {
        model: Quickshell.screens

        delegate: CalendarPopup {}
    }
}
