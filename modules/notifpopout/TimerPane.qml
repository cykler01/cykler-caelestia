pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

// The timer panel the utilities panel's timer button opens over the sidebar's tabs.
//
// NOTE(fork): three clocks share it, picked between at the top - a countdown to a length set on a
// dial, a stopwatch counting up with laps, and alarms at a time of day. Each lives in a service of
// its own (CountdownTimer, Stopwatch, Alarms) rather than here, so they keep running - and still
// ring - while the sidebar is shut, with the ring above the bar's clock and the notch's side
// bubbles carrying on where this leaves off.
ColumnLayout {
    id: root

    // 0 countdown, 1 stopwatch, 2 alarms. It opens on whatever wants attention: an alarm going off
    // first, then whichever clock is already running, and the countdown when nothing is
    property int mode: {
        if (Alarms.ringing)
            return 2;
        if (!CountdownTimer.active && Stopwatch.active)
            return 1;
        return 0;
    }

    spacing: Tokens.spacing.medium

    SegmentedBar {
        Layout.fillWidth: true

        // Names only: three segments across a sidebar leave an icon and a word fighting over the
        // same hundred pixels, and the three icons for these are all a round clock face anyway
        model: [
            {
                text: Tr.tr("Timer")
            },
            {
                text: Tr.tr("Stopwatch")
            },
            {
                text: Tr.tr("Alarm")
            }
        ]
        currentIndex: root.mode
        onActivated: index => root.mode = index
    }

    // The three sit on top of each other and cross over sideways, so switching tabs reads as the
    // panel moving along rather than as its contents being swapped out
    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        TimerView {
            anchors.fill: parent

            opacity: root.mode === 0 ? 1 : 0
            visible: opacity > 0.01

            // A translate rather than an x of its own: the view is anchored to fill the stack, and
            // anchors own x
            transform: Translate {
                x: (0 - root.mode) * Tokens.spacing.extraExtraLarge

                Behavior on x {
                    Anim {
                        type: Anim.DefaultSpatial
                    }
                }
            }

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        StopwatchView {
            anchors.fill: parent

            opacity: root.mode === 1 ? 1 : 0
            visible: opacity > 0.01

            // A translate rather than an x of its own: the view is anchored to fill the stack, and
            // anchors own x
            transform: Translate {
                x: (1 - root.mode) * Tokens.spacing.extraExtraLarge

                Behavior on x {
                    Anim {
                        type: Anim.DefaultSpatial
                    }
                }
            }

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        AlarmView {
            anchors.fill: parent

            opacity: root.mode === 2 ? 1 : 0
            visible: opacity > 0.01

            // A translate rather than an x of its own: the view is anchored to fill the stack, and
            // anchors own x
            transform: Translate {
                x: (2 - root.mode) * Tokens.spacing.extraExtraLarge

                Behavior on x {
                    Anim {
                        type: Anim.DefaultSpatial
                    }
                }
            }

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }
    }
}
