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

    // The brief pill after a track change, 
    readonly property bool trackActive: root.playing && shown

    readonly property bool shouldBeActive: Config.notch.enabled && (persistent || trackActive) && !screenState.dashboard && !screenState.launcher
    property real offsetScale: shouldBeActive ? 0 : 1

    // Services are reference counted, so cava - and the PipeWire capture it reads - stops the
    // moment the pill's own ref (in Pill.qml) goes away. Started cold it has to settle its
    // autosensitivity first, which holds the bars at nothing for a good second before they climb
    // to a visible height, and that is most of the pill's brief time on screen. Holding a ref for
    // as long as something is playing keeps it warmed up, so a track change shows a visualiser
    // that is already up to level instead of a blank pill that fills in late.
    //
    // The analyser is the most expensive thing the notch does (it runs a transform about 85 times a second for
    // as long as it is held), so it is only held this way on mains power. On battery the pill's own placeholder
    // pattern covers the first moments, and the analyser starts when a pill with a visualiser actually appears.
    ServiceRef {
        service: Config.notch.enabled && root.playing && !PowerSaving.onBattery && !PowerSaving.pauseVisualisers && PowerSaving.animations ? Audio.cava : null
    }

    // Whether the pill's visualiser is allowed to run: the brief pill after a track change always, the standing
    // one (clock plus music, kept up as long as there is something playing) only on mains power, so a track playing
    // in the background on battery doesn't keep an analyser and a redraw loop going for nobody's benefit
    readonly property bool visualiserLive: trackActive || !PowerSaving.onBattery

    // With windows open the notch sits inside the bar (where the active window's title used to be) instead of
    // hanging below the top edge: as a flat pill on a horizontal bar, rotated to read along it on a vertical one
    readonly property var barRef: ShellState.componentsFor(screen)?.bar
    // 1 once the workspace is empty, 0 with windows: one animated value owned by the drawers window, shared with the
    // bar's cut-away so the notch, the bar and the content all move on the same curve
    property real morph: 1
    readonly property real inBarProg: barRef ? 1 - morph : 0
    readonly property bool morphing: inBarProg > 0.001 && inBarProg < 0.999
    readonly property bool onVerticalBar: !!barRef && barRef.vertical

    // Where it rests inside the bar band, centred across the band's thickness (horizontal bars)
    readonly property real barY: !barRef ? 0 : barRef.onBottom ? parent.height + (barRef.insetBottom - height) / 2 : -(barRef.insetTop + height) / 2

    // Where it hangs (or rests, in the bar) in the panel area's coordinates
    readonly property real hangX: Config.notch.align === PanelAlign.Start ? 0 : Config.notch.align === PanelAlign.End ? parent.width - width : (parent.width - width) / 2
    readonly property real hangY: (-height - 5) * offsetScale
    // Centre of the bar band on a vertical bar: across its thickness, and halfway along the screen
    readonly property real barCx: !barRef ? 0 : barRef.onLeft ? -barRef.insetLeft / 2 : parent.width + barRef.insetRight / 2
    readonly property real barCy: !barRef ? 0 : (parent.height + barRef.insetBottom - barRef.insetTop) / 2

    // The background blob's own y: on a vertical bar it retreats up out of sight instead of following the (rotated)
    // content into the band
    readonly property real bgY: onVerticalBar ? (-height - 5) * (1 - (1 - offsetScale) * (1 - inBarProg)) : y

    visible: offsetScale < 1
    // Plain bindings rather than anchors, so the position can change live
    x: onVerticalBar ? (hangX + width / 2) * (1 - inBarProg) + barCx * inBarProg - width / 2 : hangX
    y: onVerticalBar ? (hangY + height / 2) * (1 - inBarProg) + barCy * inBarProg - height / 2 : hangY * (1 - inBarProg) + barY * inBarProg
    // The turn happens half way, while the content is faded out
    rotation: onVerticalBar && inBarProg > 0.5 ? (barRef.onLeft ? -90 : 90) : 0
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    opacity: 1 - offsetScale

    Behavior on offsetScale {
        Anim {}
    }

    // Fluidly resize (rather than snap) when the track title's length changes
    // the pill's natural width, matching modules/bar/popouts/Wrapper.qml
    // (not while moving in or out of the bar: the size changes there while the content is faded out, and easing it
    // on a different curve than the move is what makes the morph look uneven)
    Behavior on implicitWidth {
        enabled: !root.morphing

        Anim {}
    }

    Behavior on implicitHeight {
        enabled: !root.morphing

        Anim {}
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

        // Nothing to watch for once warm (the call per update is what it costs)
        enabled: !root.cavaWarm

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

    Loader {
        id: content

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top

        // Fades out and back in across the move into (or out of) the bar, where the layout switches size
        opacity: Math.abs(2 * root.inBarProg - 1)

        active: root.shouldBeActive || root.visible

        sourceComponent: Pill {
            local: root.local
            cavaWarm: root.cavaWarm
            allowLive: root.visualiserLive
            showMedia: root.playing && (root.trackActive || (root.persistent && Config.notch.showMusic))
            showClock: root.persistent && Config.notch.showClock
            compact: root.inBarProg > 0.5
        }
    }
}
