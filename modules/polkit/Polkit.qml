pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import qs.components.containers
import qs.services

// Registers the shell as the session's polkit authentication agent, so anything that asks for a
// password to do something privileged gets the shell's own prompt (see Content.qml) instead of
// whatever dialog the desktop would otherwise put up.
//
// polkit allows one agent per session, so whichever agent registers first is the one that is
// asked: polkit-gnome, hyprpolkitagent and the like have to be turned off for this one to take
// over. Registration is retried for a while after it is refused, since at login this is a race
// with whatever else the session starts.
Scope {
    id: root

    // Where the prompt goes. Fixed when the request arrives, so it does not jump to another
    // screen if focus moves while it is up
    property ShellScreen promptScreen

    readonly property ShellScreen focusedScreen: Screens.screens.find(s => Hypr.monitorFor(s) === Hypr.focusedMonitor) ?? Screens.screens[0]

    // Built through a loader so the retry below can throw away the refused one and ask again
    readonly property var agent: agentLoader.item

    // Whether there is a request to answer right now
    readonly property bool active: root.agent?.isActive ?? false

    // NOTE(fork): the window is held up for a moment after the request is over, so the panel can
    // collapse back into the notch instead of blinking out of existence with it (see Content.qml).
    // Nothing can be typed into it in that moment: the keyboard goes back the instant the request
    // does, and the panel has no flow left to submit to.
    property bool shown

    onActiveChanged: {
        if (root.active) {
            closeTimer.stop();
            root.shown = true;
        } else if (root.shown) {
            closeTimer.restart();
        }
    }

    Timer {
        id: closeTimer

        // Long enough for the panel's own close animation (Anim.DefaultSpatial) to finish
        interval: 600
        onTriggered: root.shown = false
    }

    Loader {
        id: agentLoader

        active: true

        sourceComponent: PolkitAgent {
            path: "/org/caelestia/PolkitAgent"

            onAuthenticationRequestStarted: root.promptScreen = root.focusedScreen
        }
    }

    StyledWindow {
        id: window

        name: "polkit"
        screen: root.promptScreen ?? root.focusedScreen

        visible: root.shown
        implicitWidth: screen.width
        implicitHeight: screen.height
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        // Holds the keyboard for as long as the prompt is up, so what gets typed into it cannot
        // reach anything underneath, and the shell's own keybinds stay out of the way
        WlrLayershell.keyboardFocus: root.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        Content {
            anchors.fill: parent

            flow: root.agent?.flow ?? null
        }
    }

    // NOTE(fork): the notch steps aside while the prompt is up, since the prompt is drawn where the
    // notch would be (see modules/polkit/Content.qml) and the two would otherwise sit on top of
    // each other
    Binding {
        target: NotchIsland
        property: "authActive"
        value: root.shown
    }

    LoggingCategory {
        id: lc

        name: "caelestia.qml.modules.polkit"
        defaultLogLevel: LoggingCategory.Warning
    }

    // Another agent holding the session is the usual reason a registration is refused, and it is
    // normally only a startup race, so keep asking for a minute before giving up. A request in
    // flight means it did register, so the retry waits rather than pulling the agent out from
    // under it
    Timer {
        id: retryTimer

        readonly property int maxAttempts: 6

        property int attempts

        interval: 10000
        repeat: true
        running: root.agent !== null && !root.agent.isRegistered && !root.active

        onTriggered: {
            if (++attempts > maxAttempts) {
                stop();
                console.warn(lc, "Polkit agent could not register - another authentication agent holds this session");
                return;
            }

            agentLoader.active = false;
            agentLoader.active = true;
        }
    }

    Connections {
        function onIsRegisteredChanged(): void {
            if (root.agent?.isRegistered)
                retryTimer.attempts = 0;
        }

        target: root.agent
    }
}
