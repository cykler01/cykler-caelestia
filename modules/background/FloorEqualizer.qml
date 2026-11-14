pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.services

// NOTE(fork): the floor equalizer - a large spectrum spanning the bottom edge of the screen,
// where the wallpaper visualiser spreads across the wallpaper itself. Levels are sampled from
// cava at the decorative rate the other visualisers use, and each bar eases between readings
// through Behavior rather than the painted item's own smoothing.
Item {
    id: root

    required property ShellScreen screen

    readonly property int barCount: Math.max(1, GlobalConfig.services.visualiserBars)
    // Kept deliberately low so it reads as an accent along the bottom edge rather than a panel
    readonly property real maxBarHeight: Math.max(56, Math.round(screen.height * 0.08))
    property var levels: []

    function barGap(available: real): real {
        if (root.barCount <= 1)
            return 0;
        // A share of each bar's slot rather than a fixed token, so the bars stay chunky at a
        // hundred across a wide screen - the same reasoning as the visualiser card's barGap
        return Math.max(1, available / root.barCount * 0.25);
    }

    implicitHeight: root.maxBarHeight

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
            for (let i = 0; i < root.barCount; i++)
                next[i] = Math.min(1, Math.max(0, values[i] ?? 0));
            root.levels = next;
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: root.barGap(parent.width)

        Repeater {
            model: root.barCount

            Item {
                required property int index

                Layout.fillWidth: true
                Layout.fillHeight: true

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    width: parent.width
                    // A 2px floor keeps the row visible in a quiet room instead of collapsing
                    height: Math.max(2, parent.height * (root.levels[index] ?? 0))
                    radius: Math.min(width / 2, height / 2)
                    color: Qt.alpha(Colours.palette.m3primary, 0.85)

                    Behavior on height {
                        Anim {
                            type: Anim.FastSpatial
                        }
                    }
                }
            }
        }
    }
}
