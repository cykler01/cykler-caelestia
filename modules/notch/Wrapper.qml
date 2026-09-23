pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// Small always-on-top-center pill that pops up briefly whenever the playing
// track changes (replacing the plain "now playing" toast), showing a mini
// visualiser plus cover/title. Hovering it peeks the Dashboard's Media tab
// (rather than duplicating that UI here) and restores whatever dashboard
// state was there before the peek once the cursor leaves.
Item {
    id: root

    required property ScreenState screenState

    property bool shown
    property bool hovered
    property bool peeking
    property bool wasAlreadyOpen
    property int previousTab

    // Stays visible through our own peek (root.peeking) so the pill keeps
    // receiving hover events to detect mouse-away and end the peek; only
    // hides for a dashboard opened some other way (e.g. the user's own keybind)
    readonly property bool shouldBeActive: Config.notch.enabled && Players.active?.isPlaying === true && (shown || hovered || peeking) && (!screenState.dashboard || root.peeking) && !screenState.launcher
    property real offsetScale: shouldBeActive ? 0 : 1

    // Media tab is inserted after Dashboard's own tab (if shown), matching the
    // filter order built in modules/dashboard/Content.qml's dashboardTabs
    readonly property int mediaTabIndex: Config.dashboard.showMedia ? (Config.dashboard.showDashboard ? 1 : 0) : -1

    function startPeek(): void {
        if (root.mediaTabIndex < 0 || !Config.dashboard.enabled)
            return;

        root.peeking = true;
        root.wasAlreadyOpen = root.screenState.dashboard;
        root.previousTab = root.screenState.dashboardTab;
        root.screenState.dashboard = true;
        root.screenState.dashboardTab = root.mediaTabIndex;
    }

    function endPeek(): void {
        if (!root.peeking)
            return;

        root.peeking = false;
        if (!root.wasAlreadyOpen)
            root.screenState.dashboard = false;
        else
            root.screenState.dashboardTab = root.previousTab;
    }

    visible: offsetScale < 1
    anchors.topMargin: (-implicitHeight - 5) * offsetScale
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    opacity: 1 - offsetScale

    Behavior on offsetScale {
        Anim {}
    }

    // Fluidly resize (rather than snap) when the track title's length changes
    // the pill's natural width, matching modules/bar/popouts/Wrapper.qml
    Behavior on implicitWidth {
        Anim {}
    }

    Behavior on implicitHeight {
        Anim {}
    }

    onShouldBeActiveChanged: {
        // e.g. playback stopped mid-peek: don't leave the dashboard force-opened
        if (!shouldBeActive && peeking)
            endPeek();
    }

    Connections {
        function onTrackChanged(): void {
            root.shown = true;
            showTimer.restart();
        }

        target: Players
    }

    Timer {
        id: showTimer

        interval: root.Config.notch.showDuration
        onTriggered: root.shown = false
    }

    Connections {
        function onIsPlayingChanged(): void {
            if (!Players.active?.isPlaying)
                root.shown = false;
        }

        target: Players.active
    }

    Timer {
        id: collapseTimer

        interval: root.Config.notch.collapseDelay
        onTriggered: root.endPeek()
    }

    Timer {
        id: expandTimer

        interval: root.Config.notch.hoverExpandDelay
        onTriggered: root.startPeek()
    }

    HoverHandler {
        onHoveredChanged: {
            root.hovered = hovered;
            if (hovered) {
                collapseTimer.stop();
                expandTimer.restart();
            } else {
                expandTimer.stop();
                collapseTimer.restart();
            }
        }
    }

    Loader {
        id: content

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top

        active: root.shouldBeActive || root.visible

        sourceComponent: Pill {}
    }
}
