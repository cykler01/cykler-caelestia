pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.services

// Small always-on-top-center pill that pops up briefly whenever the playing
// track changes (replacing the plain "now playing" toast), showing a mini
// visualiser plus cover/title. Hovering it peeks the Dashboard's Media tab
// (rather than duplicating that UI here) and restores whatever dashboard
// state was there before the peek once the cursor leaves.
//
// It follows whatever has something to say about what is playing - an MPRIS
// player, or the in-shell player - by the same rule the media tab uses to pick
// its source: with no external player open, the local player is what the pill
// is there for.
Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState

    property bool shown
    property bool hovered
    property bool peeking
    property bool wasAlreadyOpen
    property int previousTab

    // Whether cava has ever produced a spectrum with a real level in it, which is what the pill
    // uses to decide between its placeholder pattern and the real bars. Deliberately one way:
    // cava keeps the autosensitivity it has learned while it is stopped, so once it has ramped up
    // it does not have to again for the rest of the session, and a quiet passage never gets
    // mistaken for a cold start on a later pill.
    property bool cavaWarm: false

    // Whether the pill is showing the in-shell player rather than an MPRIS one. An open MPRIS
    // player wins, matching the media tab: the local player is what there is to control when
    // nothing external is open.
    readonly property bool local: !Players.active && Music.hasTrack
    readonly property bool playing: root.local ? Music.playing : Players.active?.isPlaying === true

    // Stays visible through our own peek (root.peeking) so the pill keeps
    // receiving hover events to detect mouse-away and end the peek; only
    // hides for a dashboard opened some other way (e.g. the user's own keybind)
    // No tiled windows cover this monitor's desktop (floating ones leave it visible), same rule as the desktop widgets
    readonly property var monitor: Hypr.monitorFor(screen)
    readonly property bool emptyWorkspace: monitor?.activeWorkspace?.toplevels?.values.every(t => t.lastIpcObject?.floating) ?? true

    // Up for as long as the workspace is empty, as long as there is something to show
    // Whether the notch is meant to be up on this workspace at all: empty ones and ones with windows have their own switch
    readonly property bool wanted: emptyWorkspace ? Config.notch.showOnEmptyWorkspace : Config.notch.showWithWindows
    // Whether the standing notch has music to show
    readonly property bool musicShown: Config.notch.showMusic && root.playing
    readonly property bool persistent: wanted && (Config.notch.showClock || musicShown)
    // Whether the notch is standing in for the clock, so the bar can drop its own
    readonly property bool showsClock: Config.notch.enabled && wanted && Config.notch.showClock

    // The brief pill after a track change, or while hovered/peeking
    readonly property bool trackActive: root.playing && (shown || hovered || peeking)

    readonly property bool shouldBeActive: Config.notch.enabled && (persistent || trackActive) && (!screenState.dashboard || root.peeking) && !screenState.launcher
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

    // Services are reference counted, so cava - and the PipeWire capture it reads - stops the
    // moment the pill's own ref (in Pill.qml) goes away. Started cold it has to settle its
    // autosensitivity first, which holds the bars at nothing for a good second before they climb
    // to a visible height, and that is most of the pill's brief time on screen. Holding a ref for
    // as long as something is playing keeps it warmed up, so a track change shows a visualiser
    // that is already up to level instead of a blank pill that fills in late.
    ServiceRef {
        service: Config.notch.enabled && root.playing && !PowerSaving.pauseVisualisers ? Audio.cava : null
    }

    // With windows open and a horizontal bar, the notch sits inside the bar (where the active window's title used to
    // be) as an inset pill, instead of hanging below it
    readonly property var barRef: ShellState.componentsFor(screen)?.bar
    readonly property bool inBar: !!barRef && (barRef.onTop || barRef.onBottom) && !emptyWorkspace
    property real inBarProg: inBar ? 1 : 0

    Behavior on inBarProg {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    // Where it rests inside the bar band, centred across the band's thickness
    readonly property real barY: !barRef ? 0 : barRef.onBottom ? parent.height + (barRef.insetBottom - height) / 2 : -(barRef.insetTop + height) / 2

    visible: offsetScale < 1
    // Position along the top edge (config notch.align); plain bindings, not anchors, so it can change live
    x: Config.notch.align === PanelAlign.Start ? 0 : Config.notch.align === PanelAlign.End ? parent.width - width : (parent.width - width) / 2
    y: (-height - 5) * offsetScale * (1 - inBarProg) + barY * inBarProg
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    opacity: 1 - offsetScale

    Behavior on offsetScale {
        Anim {}
    }

    // The inset pill behind the content while it sits inside the bar, in the same style as the bar's own pills
    StyledRect {
        anchors.fill: parent
        radius: Tokens.rounding.full
        color: Colours.tPalette.m3surfaceContainer
        opacity: root.inBarProg
        visible: opacity > 0
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
        // Watches the spectrum itself rather than a peak property's change signal: a passage that
        // holds the loudest bar steady for a while still has to be able to warm this up. Stops
        // costing anything at all once it has, since there is nothing left to wait for.
        function onValuesChanged(): void {
            if (root.cavaWarm)
                return;

            const values = Audio.cava.values;
            for (let i = 0; i < values.length; i++) {
                if (values[i] >= 0.4) {
                    root.cavaWarm = true;
                    return;
                }
            }
        }

        target: Audio.cava
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

    // The in-shell player has no MPRIS trackChanged to lean on, so its own track changes and
    // playback are what bring the pill up and take it back down
    Connections {
        function onCurrentFileChanged(): void {
            if (!root.local)
                return;

            root.shown = true;
            showTimer.restart();
        }

        function onPlayingChanged(): void {
            if (root.local && !Music.playing)
                root.shown = false;
        }

        target: Music
    }

    Timer {
        id: collapseTimer

        interval: root.Config.notch.collapseDelay
        onTriggered: root.endPeek()
    }

    Timer {
        id: expandTimer

        interval: root.Config.notch.hoverExpandDelay
        onTriggered: {
            // Peeking opens the media tab, which is only interesting while something is playing
            if (root.playing)
                root.startPeek();
        }
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

        // While peeking, the dashboard opens underneath this and would have the pill drawn across its tab row;
        // the pill stays in place (invisible) so it still sees the hover that keeps the peek open
        opacity: root.peeking ? 0 : 1

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        active: root.shouldBeActive || root.visible

        sourceComponent: Pill {
            local: root.local
            cavaWarm: root.cavaWarm
            showMedia: root.playing && (root.trackActive || (root.persistent && Config.notch.showMusic))
            showClock: root.persistent && Config.notch.showClock
        }
    }
}
