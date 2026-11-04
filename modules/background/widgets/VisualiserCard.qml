pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Caelestia.Components
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Models
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services
import qs.utils
import qs.modules.background
import qs.modules.dashboard.media
import qs.modules.launcher.services

// --- Visualiser: the same spectrum the background and the notch draw, on a card ---
WidgetCard {
    id: visualiser

    readonly property int barCount: Math.max(1, GlobalConfig.services.visualiserBars)
    // The mirrored variant draws the spectrum centred on the middle of the card and reflected above
    // and below that line, the same way the notch's now-playing pill draws it, rather than growing
    // from the bottom edge
    readonly property bool mirrored: visualiser.variant === "mirror"
    // Levels are sampled from cava at the shared decorative rate instead of bound straight to
    // it, so a burst of analyser updates can't rebuild the whole row
    property var levels: []

    // The gap between bars, as a share of the room each one has. A token-sized gap is right for the
    // wallpaper, which has the whole screen to spread across, but on a card it leaves 60 bars a
    // fraction of a pixel wide; taking a share of the slot instead keeps them as chunky here as
    // they are on the wallpaper. Both styles below use it, so they come out the same thickness
    function barGap(available: real): real {
        if (visualiser.barCount <= 1)
            return 0;
        return Math.max(0.5, available / visualiser.barCount * 0.28);
    }

    title: Tr.tr("Visualiser")
    icon: "graphic_eq"

    // Cava, and the PipeWire capture behind it, only runs while something references it
    ServiceRef {
        service: PowerSaving.pauseVisualisers ? null : Audio.cava
    }

    Timer {
        // The row of rectangles rebinds every bar on each new set of levels, so it is fed at the shared
        // decorative rate. The painted bars smooth themselves, and holding each reading for two or three
        // frames made the mirrored variant step at the analyser's rate under an easing that runs every
        // frame: the bars visibly ticked rather than flowed, next to a row that moved continuously
        interval: visualiser.mirrored ? 16 : PowerSaving.frameMs
        repeat: true
        triggeredOnStart: true
        running: visualiser.visible && !PowerSaving.pauseVisualisers

        onTriggered: {
            const values = Audio.cava.values;
            // A little floor in the mirrored variant as well, so a quiet room leaves a line on the
            // middle of the card rather than nothing at all (the row below has its own 2px floor)
            const floor = visualiser.mirrored ? 0.02 : 0;
            const next = new Array(visualiser.barCount);
            for (let i = 0; i < visualiser.barCount; i++)
                next[i] = Math.min(1, Math.max(floor, values[i] ?? 0));
            visualiser.levels = next;
        }
    }

    Item {
        id: plot

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 80

        // The mirrored variant is the shell's own painted spectrum (see
        // plugin/src/Caelestia/Components/visualiserbars.hpp), told to centre on the middle line and
        // reflect each bar above and below it
        VisualiserBars {
            id: bars

            anchors.fill: parent
            visible: visualiser.mirrored

            mirrored: true
            singleRow: true
            values: visualiser.levels
            // Solid primary, the same colour the row below and the wallpaper draw with: the gradient
            // this used to carry (primary at the tips, inversePrimary along the middle line) read as
            // washed out here, where most of a bar sits close to that middle line
            primaryColor: Colours.palette.m3primary
            secondaryColor: Colours.palette.m3primary
            rounding: Tokens.rounding.small
            spacing: visualiser.barGap(plot.width)
            animationDuration: Tokens.anim.durations.normal
        }

        // The painted bars ease towards their latest levels themselves, so they have to be stepped
        // every frame. The row below does the same job through Behavior, which the scene graph drives
        // on its own; stepping these from the sampling timer instead made the mirrored variant run at
        // the analyser's rate rather than the screen's, which read as noticeably choppier. While the
        // bars are at rest advance() returns straight away and requests no repaint, so a quiet card
        // costs nothing beyond the tick
        FrameAnimation {
            running: visualiser.mirrored && visualiser.visible && !bars.settled
            onTriggered: bars.advance(frameTime)
        }

        RowLayout {
            anchors.fill: parent
            visible: !visualiser.mirrored
            spacing: visualiser.barGap(plot.width)

            Repeater {
                model: visualiser.barCount

                Item {
                    required property int index

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // A bar grows up from the bottom of its own slot; the 2px floor keeps the
                    // row visible while the room is quiet instead of collapsing to nothing
                    StyledRect {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: Math.max(2, parent.height * (visualiser.levels[index] ?? 0))
                        radius: Math.min(width / 2, height / 2)
                        color: Colours.palette.m3primary

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
}
