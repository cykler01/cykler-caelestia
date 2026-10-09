import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import qs.components.misc
import qs.services
import qs.modules.nexus

Scope {
    id: root

    property bool launcherInterrupted
    readonly property bool hasFullscreen: Hypr.focusedWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "nexus"
        description: "Open nexus"
        onPressed: WindowFactory.create()
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "showall"
        description: "Toggle launcher, dashboard and osd"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const v = ShellState.forActive();
            v.launcher = v.dashboard = v.osd = v.utilities = !(v.launcher || v.dashboard || v.osd || v.utilities);
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "dashboard"
        description: "Toggle dashboard"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const screenState = ShellState.forActive();
            screenState.dashboard = !screenState.dashboard;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "session"
        description: "Toggle session menu"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const screenState = ShellState.forActive();
            screenState.session = !screenState.session;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "launcher"
        description: "Toggle launcher"
        onPressed: root.launcherInterrupted = false
        onReleased: {
            if (!root.launcherInterrupted && !root.hasFullscreen) {
                const screenState = ShellState.forActive();
                screenState.launcher = !screenState.launcher;
            }
            root.launcherInterrupted = false;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "launcherInterrupt"
        description: "Interrupt launcher keybind"
        onPressed: root.launcherInterrupted = true
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        // Notifications, the media library and the to-do list are tabs of the sidebar's own top
        // card (see modules/sidebar/Content.qml), along with the notepad, rather than a separate
        // popout
        name: "notifPopoutOpen"
        description: "Open the sidebar"
        onPressed: {
            if (!root.hasFullscreen)
                ShellState.forActive().sidebar = true;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "notifPopoutClose"
        description: "Close the sidebar"
        onPressed: {
            const screenState = ShellState.forActive();
            // With the overview up the same swipe turns its page instead
            if (screenState.overview)
                screenState.overviewPageRequested(-1);
            else
                screenState.sidebar = false;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        // What the sidebar's left swipe does: opening it the first time, then moving between its
        // tabs on every swipe after that, since a gesture can only carry one action
        name: "notifPopoutOpenOrNextTab"
        description: "Open the sidebar, or switch its tab"
        onPressed: {
            const screenState = ShellState.forActive();
            if (screenState.overview) {
                screenState.overviewPageRequested(1);
                return;
            }

            if (!screenState.sidebar) {
                screenState.sidebar = true;
                return;
            }

            // Notifications, the media library, the to-do list and the notepad, then back to the first
            screenState.notifPopoutTab = (screenState.notifPopoutTab + 1) % 4;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "overviewOpen"
        description: "Open the overview"
        onPressed: {
            if (!root.hasFullscreen)
                ShellState.forActive().overview = true;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "overviewClose"
        description: "Close the overview"
        onPressed: ShellState.forActive().overview = false
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "overview"
        description: "Toggle the overview"
        onPressed: {
            const screenState = ShellState.forActive();
            if (!screenState.overview && root.hasFullscreen)
                return;
            screenState.overview = !screenState.overview;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        // The to-do list is the sidebar's third tab rather than a panel of its own
        name: "todoPopout"
        description: "Toggle the to-do list"
        onPressed: {
            const screenState = ShellState.forActive();
            const isTodoOpen = screenState.sidebar && screenState.notifPopoutTab === 2;
            if (isTodoOpen) {
                screenState.sidebar = false;
            } else {
                if (root.hasFullscreen)
                    return;
                screenState.notifPopoutTab = 2;
                screenState.sidebar = true;
            }
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        // The notepad is the sidebar's fourth tab rather than a panel of its own
        name: "notepadPopout"
        description: "Toggle the notepad"
        onPressed: {
            const screenState = ShellState.forActive();
            const isNotepadOpen = screenState.sidebar && screenState.notifPopoutTab === 3;
            if (isNotepadOpen) {
                screenState.sidebar = false;
            } else {
                if (root.hasFullscreen)
                    return;
                screenState.notifPopoutTab = 3;
                screenState.sidebar = true;
            }
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "sidebar"
        description: "Toggle sidebar"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const screenState = ShellState.forActive();
            screenState.sidebar = !screenState.sidebar;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "utilities"
        description: "Toggle utilities"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const screenState = ShellState.forActive();
            screenState.utilities = !screenState.utilities;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        // Same script the launcher's own "ocr"/"lens" action runs (see
        // modules/launcher/services/Actions.qml), just reachable without opening the launcher first
        name: "ocr"
        description: "Run OCR"
        onPressed: Quickshell.execDetached(["bash", `${Quickshell.shellDir}/assets/ocr.sh`])
    }

    IpcHandler {
        function toggle(drawer: string): void {
            if (list().split("\n").includes(drawer)) {
                if (root.hasFullscreen && ["launcher", "session", "dashboard"].includes(drawer))
                    return;
                const screenState = ShellState.forActive();
                screenState[drawer] = !screenState[drawer];
            } else {
                console.warn(lc, `Drawer "${drawer}" does not exist`);
            }
        }

        function list(): string {
            const screenState = ShellState.forActive();
            return Object.keys(screenState).filter(k => typeof screenState[k] === "boolean").join("\n");
        }

        function isOpen(drawer: string): string {
            const screenState = ShellState.forActive();
            if (typeof screenState[drawer] !== "boolean")
                return "unknown";
            return screenState[drawer] ? "1" : "0";
        }

        target: "drawers"
    }

    IpcHandler {
        function open(): void {
            WindowFactory.create();
        }

        target: "nexus"
    }

    IpcHandler {
        function info(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Info);
        }

        function success(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Success);
        }

        function warn(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Warning);
        }

        function error(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Error);
        }

        target: "toaster"
    }

    LoggingCategory {
        id: lc

        name: "caelestia.qml.shortcuts"
        defaultLogLevel: LoggingCategory.Info
    }
}
