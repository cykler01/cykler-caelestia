pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.services
import qs.modules.background.widgets

// NOTE(fork): the floor equalizer - a large spectrum spanning the bottom edge of the screen,
// where the wallpaper visualiser spreads across the wallpaper itself. Levels are sampled from
// cava at the decorative rate the other visualisers use, and each bar eases between readings
// through Behavior rather than the painted item's own smoothing.
//
// Config.background.floorEqualizer.position hangs it from the top instead ("ceiling"), and
// .style swaps the bars for the wallpaper visualiser's wave ("wave") or just its outline
// ("line"), mirrored top to bottom on the ceiling so the crests point down into the screen
Item {
    id: root

    required property ShellScreen screen

    readonly property int barCount: Math.max(1, GlobalConfig.services.visualiserBars)
    // Kept deliberately low so it reads as an accent along the bottom edge rather than a panel,
    // then scaled by the amplitude set in Nexus > Panels
    readonly property real amplitude: Math.max(0.5, Math.min(3, Config.background.floorEqualizer.amplitude ?? 1))
    // How slowly the levels are eased towards each reading, set in Nexus > Panels: 1 is the
    // original feel, 0 snaps straight to every reading
    readonly property real smoothness: Math.max(0, Math.min(2, Config.background.floorEqualizer.smoothness ?? 1))
    // How a level (0-1) maps to height, set in Nexus > Panels. The frequency side is already
    // logarithmic (cava spreads the bands over 50 Hz - 10 kHz on a log scale), so this is only
    // the loudness response
    readonly property string response: Config.background.floorEqualizer.response ?? "linear"
    readonly property real maxBarHeight: Math.round(Math.max(56, screen.height * 0.08) * root.amplitude)
    property var levels: []

    // NOTE(fork): whether anything has made a sound lately. Read off the levels themselves rather
    // than a media player's state, so any audio counts (a video in the browser, a game) and not
    // only music. Starts false so it fades in on the first sound rather than flashing up idle
    property bool hearing: false
    readonly property bool autoHide: Config.background.floorEqualizer.autoHide ?? true
    // A quiet room still reads a hair above zero, so anything at or under this counts as silence
    readonly property real silenceLevel: 0.02

    readonly property bool ceiling: (Config.background.floorEqualizer.position ?? "floor") === "ceiling"
    readonly property string style: {
        const s = Config.background.floorEqualizer.style ?? "bars";
        return s === "wave" || s === "line" ? s : "bars";
    }

    function shape(v: real): real {
        switch (root.response) {
        case "log":
            // Decibel-like: log10(1 + 9v) runs 0 -> 1 over 0 -> 1 but rises steeply early on
            return Math.log10(1 + 9 * v);
        case "sqrt":
            return Math.sqrt(v);
        case "exp":
            return v * v;
        }
        return v;
    }

    function barGap(available: real): real {
        if (root.barCount <= 1)
            return 0;
        // A share of each bar's slot rather than a fixed token, so the bars stay chunky at a
        // hundred across a wide screen - the same reasoning as the visualiser card's barGap
        return Math.max(1, available / root.barCount * 0.25);
    }

    implicitHeight: root.maxBarHeight
    // Faded rather than hidden: the sampling below stops with visibility, and it is what notices
    // the sound coming back
    opacity: !root.autoHide || root.hearing ? 1 : 0

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    // Cava, and the PipeWire capture behind it, only runs while something references it
    ServiceRef {
        service: PowerSaving.pauseVisualisers ? null : Audio.cava
    }

    Timer {
        interval: PowerSaving.frameMs
        repeat: true
        triggeredOnStart: true
        running: root.visible && !PowerSaving.pauseVisualisers

        onTriggered: {
            const values = Audio.cava.values;
            const next = new Array(root.barCount);
            let loudest = 0;
            for (let i = 0; i < root.barCount; i++) {
                const raw = Math.min(1, Math.max(0, values[i] ?? 0));
                // Silence is judged on the raw level, so the response curve can't change when it hides
                loudest = Math.max(loudest, raw);
                next[i] = Math.min(1, Math.max(0, root.shape(raw)));
            }
            root.levels = next;

            if (loudest > root.silenceLevel) {
                root.hearing = true;
                silenceTimer.restart();
            }
        }
    }

    // How long it has to stay quiet before it fades, so a gap between tracks or a quiet bar in a
    // song doesn't make it blink out
    Timer {
        id: silenceTimer

        interval: 2000
        onTriggered: root.hearing = false
    }

    RowLayout {
        anchors.fill: parent
        visible: root.style === "bars"
        spacing: root.barGap(parent.width)

        Repeater {
            model: root.barCount

            Item {
                required property int index

                Layout.fillWidth: true
                Layout.fillHeight: true

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    // Grown up from the floor, or down from the ceiling
                    anchors.bottom: root.ceiling ? undefined : parent.bottom
                    anchors.top: root.ceiling ? parent.top : undefined
                    width: parent.width
                    // A 2px floor keeps the row visible in a quiet room instead of collapsing
                    height: Math.max(2, parent.height * (root.levels[index] ?? 0))
                    radius: Math.min(width / 2, height / 2)
                    color: Qt.alpha(Colours.palette.m3primary, 0.85)

                    Behavior on height {
                        enabled: root.smoothness > 0

                        Anim {
                            type: Anim.FastSpatial
                            // The type's own duration, stretched or shortened by the smoothness
                            // (and still nothing with animations switched off)
                            duration: PowerSaving.animations ? Tokens.anim.durations.expressiveFastSpatial * root.smoothness : 0
                        }
                    }
                }
            }
        }
    }

    Loader {
        anchors.fill: parent
        active: root.style !== "bars"
        asynchronous: true

        sourceComponent: VisualiserWave {
            levels: root.levels
            barCount: root.barCount
            outlineOnly: root.style === "line"
            smoothing: root.smoothness
            // Drawn floor-up, so flipped for the ceiling
            transform: Scale {
                origin.y: root.height / 2
                yScale: root.ceiling ? -1 : 1
            }
        }
    }
}
