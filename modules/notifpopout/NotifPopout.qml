pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Notification popout opened by a 4-finger swipe (see the Hyprland gestures).
Scope {
    id: root

    readonly property string namespaceMatch: "caelestia-notifpopout.*"

    readonly property bool anyOpen: Screens.screens.some(s => ShellState.forScreen(s).notifPopout)

    property bool rulesApplied

    // Once per config load (a reload drops layer rules); a rule added before the
    // Hyprland connection has settled is silently lost, so this waits for that
    function ensureRules(): void {
        if (rulesApplied)
            return;
        rulesApplied = true;

        let rule, on;
        if (Hypr.usingLua) {
            rule = `eval hl.layer_rule({ match = { namespace = "${namespaceMatch}" }, %1 = %2 })`;
            on = true;
        } else {
            rule = `keyword layerrule %1 %2, match:namespace ${namespaceMatch}`;
            on = 1;
        }
        // Blur even the translucent parts, unlike the drawers window
        // Hyprland would otherwise play its own layer animation on top of ours
        Hypr.extras.batchMessage([rule.arg("blur").arg(on), rule.arg("ignore_alpha").arg(0.2), rule.arg("no_anim").arg(on)]);
    }

    function setActive(open: bool): void {
        const state = ShellState.forActive();
        if (state)
            state.notifPopout = open;
    }

    onAnyOpenChanged: {
        if (anyOpen)
            ensureRules();
    }

    Timer {
        interval: 1500
        running: true
        onTriggered: root.ensureRules()
    }

    Connections {
        function onConfigReloaded(): void {
            root.rulesApplied = false;
            root.ensureRules();
        }

        target: Hypr
    }

    IpcHandler {
        function open(): void {
            root.setActive(true);
        }

        function close(): void {
            root.setActive(false);
        }

        function toggle(): void {
            const state = ShellState.forActive();
            if (state)
                state.notifPopout = !state.notifPopout;
        }

        target: "notifPopout"
    }

    Variants {
        model: Screens.screens

        PopoutWindow {
            required property ShellScreen modelData

            screen: modelData
        }
    }
}
