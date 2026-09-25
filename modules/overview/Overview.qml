import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Overview of all workspaces and their windows, opened by a 4-finger swipe up
// or the top-left hot corner. See ShellState.overview.
Scope {
    id: root

    readonly property string namespaceMatch: "caelestia-overview"

    property bool rulesApplied

    // The overview blurs what is behind it instead of only dimming it, which the compositor
    // does for a layer once it is asked to. Once per config load (a reload drops layer rules),
    // and not before the Hyprland connection has settled or the rule is silently lost.
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
        // Blur the scrim even though it is mostly transparent. Hyprland's own fade is kept: the
        // blur can only be faded by the compositor, so without it the blur would pop in and out.
        Hypr.extras.batchMessage([rule.arg("blur").arg(on), rule.arg("ignore_alpha").arg(0.02), rule.arg("animation").arg(Hypr.usingLua ? '"fade"' : "fade")]);
    }

    function setActive(open: bool): void {
        const state = ShellState.forActive();
        if (state)
            state.overview = open;
    }

    function toggle(): void {
        const state = ShellState.forActive();
        if (state)
            state.overview = !state.overview;
    }

    Component.onCompleted: rulesTimer.start()

    Timer {
        id: rulesTimer

        interval: 1500
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
            root.toggle();
        }

        // Closes the overview if it is open and says whether it was, so a gesture shared with
        // something else (a four-finger swipe down that also suspends, say) can tell them apart
        function closeIfOpen(): bool {
            const state = ShellState.forActive();
            const wasOpen = state?.overview ?? false;
            if (wasOpen)
                state.overview = false;
            return wasOpen;
        }

        target: "overview"
    }

    Variants {
        model: Screens.screens

        OverviewWindow {
            required property ShellScreen modelData

            screen: modelData
        }
    }
}
