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
        name: "notifPopoutOpen"
        description: "Open the notification popout"
        onPressed: {
            if (!root.hasFullscreen)
                ShellState.forActive().notifPopout = true;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "notifPopoutClose"
        description: "Close the notification popout"
        onPressed: {
            const screenState = ShellState.forActive();
            // With the overview up the same swipe turns its page instead
            if (screenState.overview)
                screenState.overviewPageRequested(-1);
            else
                screenState.notifPopout = false;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        // What the popout's left swipe does: opening it the first time, then moving
        // between its tabs on every swipe after that, since a gesture can only carry
        // one action
        name: "notifPopoutOpenOrNextTab"
        description: "Open the notification popout, or switch it to its next tab"
        onPressed: {
            const screenState = ShellState.forActive();
            if (screenState.overview) {
                screenState.overviewPageRequested(1);
                return;
            }

            if (!screenState.notifPopout) {
                screenState.notifPopout = true;
                return;
            }

            // Notifications and the media library, so the next tab is the other one
            screenState.notifPopoutTab = screenState.notifPopoutTab === 0 ? 1 : 0;
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
