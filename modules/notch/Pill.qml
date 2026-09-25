import QtQuick
import QtQuick.Layouts
import Caelestia.Components
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.components.widgets
import qs.services

// No background/border/shadow here - the shared blob group in
// modules/drawers/ContentWindow.qml (PanelBg { panel: panels.notch }) paints
// the fluid, deforming background behind this, same as every other drawer
// panel (dashboard, osd, popouts, etc.). This is just the foreground content.
Item {
    id: root

    // Set by the Wrapper: whether cava has a real level to draw yet (see cavaWarm there), and
    // whether what is playing is the in-shell player rather than an MPRIS one
    property bool cavaWarm
    property bool local
    // What to show: the playing track (cover, title, visualiser) and/or the clock
    property bool showMedia: true
    property bool showClock

    // Eased 0..1 versions of the above so the clock (and its divider) grow in and out instead of snapping
    property real clockProg: showClock ? 1 : 0
    property real dividerProg: showClock && showMedia ? 1 : 0

    Behavior on clockProg {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    Behavior on dividerProg {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    // Whether the visualiser moves at all: not while Power & battery has visualisers paused or animations off
    // Set by the wrapper: false for a standing pill on battery
    property bool allowLive: true
    readonly property bool live: allowLive && !PowerSaving.pauseVisualisers && PowerSaving.animations

    // What the bars show, refreshed at the shared decorative rate by the timer below. It used to be a binding on the
    // analyser's output, which re-ran the grouping (and allocated a list) on every one of its ~85 updates a second.
    property var spectrum: Array(barCount).fill(0.2)

    // Sitting inside the bar rather than hanging from it: smaller everything, one line, no date
    property bool compact

    readonly property int coverSize: compact ? Tokens.padding.large + 4 : Tokens.padding.extraLarge

    // Drives the placeholder pattern below; only ticks while that pattern is actually on screen
    property real placeholderPhase

    // The bars are drawn as one row across the full width of the visualiser box (see singleRow
    // below), so the count has to follow the size of the pill: more than this and they come out
    // narrower than the gaps between them
    readonly property int barCount: Math.max(3, Math.round(root.coverSize / 5))

    // Groups the shell's full-width spectrum down to the bars the pill has room for, taking the
    // peak of each group so a band sitting next to a loud one doesn't disappear
    function sampleSpectrum(values: var, count: int): var {
        const bars = [];
        if (!values || values.length === 0)
            return bars;

        const step = values.length / count;
        for (let i = 0; i < count; i++) {
            const start = Math.floor(i * step);
            const end = Math.max(start + 1, Math.floor((i + 1) * step));
            let peak = 0;
            for (let j = start; j < end && j < values.length; j++)
                peak = Math.max(peak, values[j]);
            bars.push(peak);
        }
        return bars;
    }

    // Stands in for the spectrum until cava has a level to report, so the first pill of a session
    // (where cava is starting cold and its autosensitivity takes about a second to ramp the bars
    // up from nothing) shows a moving equaliser rather than an empty box. Two detuned waves per
    // bar, under an envelope that lifts the middle bars, so it reads as a spectrum rather than a
    // row of pulsing dots. Runs 0.25 to 0.65, the height range the real bars hand over in, so the
    // swap does not read as a jump.
    function placeholderSpectrum(count: int): var {
        const bars = [];
        for (let i = 0; i < count; i++) {
            const envelope = 0.55 + 0.45 * (1 - Math.abs((i + 0.5) / count * 2 - 1));
            const wave = 0.5 + 0.32 * Math.sin(root.placeholderPhase * (1 + i * 0.19) + i * 1.7) + 0.18 * Math.sin(root.placeholderPhase * (2.2 + i * 0.11) + i * 0.7);
            bars.push(0.25 + 0.4 * envelope * wave);
        }
        return bars;
    }

    implicitWidth: layout.implicitWidth + (compact ? Tokens.padding.medium : Tokens.padding.large) * 2
    implicitHeight: layout.implicitHeight + (compact ? Tokens.padding.small : Tokens.padding.medium) * 2

    RowLayout {
        id: layout

        anchors.centerIn: parent
        spacing: Tokens.spacing.medium

        // Grows and fades in rather than popping; the box's width follows the clock's own
        Item {
            visible: root.clockProg > 0
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: clockColumn.implicitWidth * root.clockProg
            implicitHeight: clockColumn.implicitHeight
            opacity: root.clockProg
            clip: true

            ColumnLayout {
                id: clockColumn

                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 0

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        text: `${Time.hourStr}:${Time.minuteStr}`
                        color: Colours.palette.m3primary
                        font: root.compact ? Tokens.font.label.builders.large.weight(Font.DemiBold).build() : Tokens.font.title.builders.small.weight(Font.DemiBold).build()
                    }

                    StyledText {
                        visible: Units.twelveHourClock
                        text: Time.amPmStr.toLowerCase()
                        color: Colours.palette.m3primary
                        font: Tokens.font.label.small
                    }
                }

                StyledText {
                    visible: !root.compact
                    Layout.alignment: Qt.AlignHCenter
                    text: Time.format("ddd d MMM")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                }
            }
        }

        StyledRect {
            visible: root.dividerProg > 0
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: root.dividerProg
            Layout.preferredHeight: root.coverSize
            opacity: root.dividerProg
            color: Colours.palette.m3outlineVariant
        }

        CoverArt {
            visible: root.showMedia
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: root.coverSize
            Layout.preferredHeight: root.coverSize
            source: root.local ? Music.coverPath : Players.getArtUrl(Players.active)
            // Turns only while the pill is allowed to animate (the same rule as the visualiser): a rotating shape
            // inside two effect layers redraws every frame, which was most of what music cost in the notch
            spinning: root.live && (root.local ? Music.playing : (Players.active?.isPlaying ?? false))
        }

        StyledText {
            visible: root.showMedia
            // Grows with the track title (and artist, if shown), elided past
            // this so one long name can't stretch the pill indefinitely
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: root.compact ? Math.min(Config.notch.maxTitleWidth, 200) : Config.notch.maxTitleWidth
            text: {
                const title = root.local ? Music.title : Players.active?.trackTitle ?? "";
                const artist = root.local ? Music.artist : Players.active?.trackArtist ?? "";
                return Config.notch.showArtist && artist ? Tr.trCtx("%1 - %2", "track artist and title").arg(artist).arg(title) : title;
            }
            color: Colours.palette.m3onSurface
            font: root.compact ? Tokens.font.label.large : Tokens.font.title.small
            elide: Text.ElideRight
        }

        Item {
            id: visualiserWrapper

            // Matches root.coverSize so the cover and visualiser carry the
            // same visual weight either side of the title
            visible: root.showMedia
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: root.coverSize
            Layout.preferredHeight: root.coverSize

            // Power Saver can pause audio capture; the bars then rest flat (see PowerSaving)
            ServiceRef {
                service: !root.live || !root.showMedia ? null : Audio.cava
            }

            VisualiserBars {
                id: bars

                anchors.fill: parent

                // Centred on the middle line and reflected above and below it rather than rising
                // from the bottom of the pill, where the bars sat low enough to be easy to miss,
                // and as one spectrum across the width: the component's default layout would
                // draw this same spectrum twice, mirrored beside itself
                // (see mirrored/singleRow in plugin/src/Caelestia/Components/visualiserbars.hpp)
                mirrored: true
                singleRow: true
                values: root.spectrum
                primaryColor: Colours.palette.m3primary
                secondaryColor: Colours.palette.m3inversePrimary
                rounding: Tokens.rounding.small
                // A quarter of the smallest spacing token: the bars here are only a few pixels
                // wide, so a full-sized gap between them would swallow them whole
                spacing: Tokens.spacing.extraSmall / 4
                animationDuration: Tokens.anim.durations.normal
            }

            // The one thing that moves the visualiser, at the shared decorative rate (PowerSaving.fps). It replaces
            // frame-driven animations: those ask for a redraw on every screen refresh for as long as they run, which
            // kept the whole shell window redrawing at full rate (and most of its power) for a few small bars. When
            // the pill is at rest (not live) nothing runs at all.
            Timer {
                property real last

                interval: PowerSaving.frameMs
                repeat: true
                triggeredOnStart: true
                running: root.showMedia && root.live
                onRunningChanged: last = Date.now()
                onTriggered: {
                    const now = Date.now();
                    const dt = Math.min(0.25, (now - last) / 1000);
                    last = now;

                    if (!root.cavaWarm)
                        root.placeholderPhase += dt * 4;
                    root.spectrum = root.cavaWarm ? root.sampleSpectrum(Audio.cava.values, root.barCount) : root.placeholderSpectrum(root.barCount);
                    if (!bars.settled)
                        bars.advance(dt);
                }
            }

            // Not live: the bars come to rest flat and stay there, without anything running
            function rest(): void {
                root.spectrum = Array(root.barCount).fill(0.2);
                Qt.callLater(() => bars.advance(1));
            }

            Connections {
                function onLiveChanged(): void {
                    if (!root.live)
                        visualiserWrapper.rest();
                }

                target: root
            }

            Component.onCompleted: {
                if (!root.live)
                    rest();
            }
        }
    }
}
