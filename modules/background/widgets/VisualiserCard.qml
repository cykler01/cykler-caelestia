pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
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
    // Levels are sampled from cava at the shared decorative rate instead of bound straight to
    // it, so a burst of analyser updates can't rebuild the whole row
    property var levels: []

    title: Tr.tr("Visualiser")
    icon: "graphic_eq"

    // Cava, and the PipeWire capture behind it, only runs while something references it
    ServiceRef {
        service: PowerSaving.pauseVisualisers ? null : Audio.cava
    }

    Timer {
        interval: PowerSaving.frameMs
        repeat: true
        triggeredOnStart: true
        running: visualiser.visible && !PowerSaving.pauseVisualisers

        onTriggered: {
            const values = Audio.cava.values;
            const next = new Array(visualiser.barCount);
            for (let i = 0; i < visualiser.barCount; i++)
                next[i] = Math.min(1, Math.max(0, values[i] ?? 0));
            visualiser.levels = next;
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 80

        RowLayout {
            anchors.fill: parent
            spacing: Tokens.spacing.extraSmall

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
