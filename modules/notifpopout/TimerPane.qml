pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services

// The timer panel the utilities panel's timer button opens over the sidebar's tabs.
//
// NOTE(fork): two clocks share it, picked between at the top - a countdown to a length you set,
// and a stopwatch counting up with laps. Both live in services of their own (CountdownTimer,
// Stopwatch) rather than here, so they keep running - and the countdown still rings - while the
// sidebar is shut, with the ring above the bar's clock and the notch's side bubble carrying on
// where this leaves off.
ColumnLayout {
    id: root

    // 0 is the countdown, 1 the stopwatch. It opens on whichever one is already going, so a panel
    // opened to check on something lands on the thing that is running
    property int mode: CountdownTimer.active || !Stopwatch.active ? 0 : 1

    spacing: Tokens.spacing.medium

    SegmentedBar {
        id: modeBar

        Layout.fillWidth: true

        model: [
            {
                icon: "timer",
                text: Tr.tr("Timer")
            },
            {
                icon: "timelapse",
                text: Tr.tr("Stopwatch")
            }
        ]
        currentIndex: root.mode
        onActivated: index => root.mode = index
    }

    // ---------------- Countdown ----------------

    TimerView {
        visible: root.mode === 0
        enabled: root.mode === 0
    }

    // ---------------- Stopwatch ----------------

    StopwatchView {
        visible: root.mode === 1
        enabled: root.mode === 1
    }

    component TimerView: ColumnLayout {
        id: timerView

        // From half a minute to two hours. Enough to cover a brew, a pomodoro, a wash and a roast
        // without anyone having to type a time in - and anything else still can be
        readonly property var presets: [30, 60, 120, 180, 300, 600, 900, 1200, 1800, 2700, 3600, 7200]
        // What the quick adjustments move it by. The small ones for nudging a preset into shape,
        // the big ones for getting across the range quickly
        readonly property var nudges: [-300, -60, 60, 300]

        readonly property string statusText: {
            if (CountdownTimer.finished)
                return Tr.tr("Time's up");
            if (CountdownTimer.running)
                return Tr.tr("Ends at %1").arg(Qt.formatTime(new Date(CountdownTimer.endAt), Units.twelveHourClock ? "h:mm A" : "HH:mm"));
            if (CountdownTimer.active)
                return Tr.tr("Paused with %1 left").arg(CountdownTimer.display);
            return Tr.tr("Ready to start");
        }

        // A length as short a label as it can be: "30 s", "5 min", "2 h". The chips are three to a
        // row, so anything longer than that would elide
        function presetLabel(secs: int): string {
            if (secs < 60)
                // TRANSLATORS: %1 = a number of seconds, kept short for a button
                return Tr.trCtx("%1 s", "a length of time, abbreviated").arg(secs);
            if (secs < 3600)
                // TRANSLATORS: %1 = a number of minutes, kept short for a button
                return Tr.trCtx("%1 min", "a length of time, abbreviated").arg(Math.round(secs / 60));
            // TRANSLATORS: %1 = a number of hours, kept short for a button
            return Tr.trCtx("%1 h", "a length of time, abbreviated").arg(Math.round(secs / 3600) );
        }

        // A lone number is minutes, "1:30" is a minute and a half and "1:02:30" an hour, two minutes
        // and a half. Zero comes back for anything that is not a time, so the caller can leave the
        // timer alone
        function durationFrom(text: string): int {
            const value = text.trim();
            if (value === "")
                return 0;

            const parts = value.split(":");
            if (parts.length > 3)
                return 0;

            const nums = parts.map(part => Number(part.trim()));
            if (nums.some(num => isNaN(num) || num < 0))
                return 0;

            if (nums.length === 1)
                return Math.round(nums[0] * 60);
            return Math.round(nums.reduce((total, num) => total * 60 + num, 0));
        }

        // A day is more than anyone needs, and keeps a slipped keystroke from setting a timer that
        // never rings
        function commitTime(value: string): void {
            const secs = timerView.durationFrom(value);
            if (secs > 0)
                CountdownTimer.setDuration(Math.min(secs, 24 * 3600));
        }

        // Moves the set length by `by` seconds, staying inside what can be set at all
        function nudge(by: int): void {
            CountdownTimer.setDuration(Math.max(1, Math.min(24 * 3600, CountdownTimer.durationSecs + by)));
        }

        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Tokens.spacing.medium

        // The ring, with the time in the middle of it: click it to type over the time
        Item {
            id: ring

            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 180
            implicitHeight: 180

            CircularProgress {
                anchors.fill: parent
                strokeWidth: 10
                value: CountdownTimer.progress
                fgColour: CountdownTimer.finished ? Colours.palette.m3tertiary : Colours.palette.m3primary
                bgColour: Colours.palette.m3surfaceContainerHighest

                Behavior on clampedVal {
                    Anim {}
                }
            }

            StyledText {
                anchors.centerIn: parent
                opacity: entry.activeFocus ? 0 : 1
                text: CountdownTimer.displayHms
                color: Colours.palette.m3onSurface
                font: Tokens.font.clock.size(Tokens.font.title.medium.pointSize).weight(Font.Bold).build()
            }

            // The same place, as a field for as long as it holds the keyboard. The readout is hidden
            // rather than swapped away, so a click that never gets the keyboard leaves the time on show
            StyledTextField {
                id: entry

                anchors.centerIn: parent
                width: 152

                type: StyledTextField.Filled
                enabled: !CountdownTimer.running
                opacity: activeFocus ? 1 : 0
                horizontalAlignment: TextInput.AlignHCenter
                verticalPadding: Tokens.padding.small
                font: Tokens.font.clock.size(Tokens.font.title.small.pointSize).weight(Font.Bold).build()
                validator: RegularExpressionValidator {
                    regularExpression: /[0-9:]{0,8}/
                }

                // Filled in with what is on the ring now, ready to be typed over
                onActiveFocusChanged: {
                    if (activeFocus) {
                        text = CountdownTimer.displayHms;
                        selectAll();
                    } else {
                        timerView.commitTime(text);
                    }
                }

                onAccepted: {
                    timerView.commitTime(text);
                    entry.focus = false;
                }
            }

            // Anywhere in the ring starts the entry, not just the time itself
            MouseArea {
                anchors.fill: parent
                enabled: !CountdownTimer.running && !entry.activeFocus
                cursorShape: Qt.IBeamCursor
                onClicked: entry.forceActiveFocus()
            }
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: timerView.statusText
            animate: true
            color: CountdownTimer.finished ? Colours.palette.m3tertiary : Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.medium
        }

        // Nudges either way, for a length that is nearly right
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall

            Repeater {
                model: timerView.nudges

                TextButton {
                    required property int modelData

                    Layout.fillWidth: true
                    // TRANSLATORS: %1 = a signed length such as "5 min", making "-5 min" or "+5 min"
                    text: (modelData < 0 ? "−" : "+") + timerView.presetLabel(Math.abs(modelData))
                    type: TextButton.Text
                    horizontalPadding: Tokens.padding.extraSmall
                    disabled: CountdownTimer.running
                    onClicked: timerView.nudge(modelData)
                }
            }
        }

        // The lengths that cover most of it, three to a row
        GridLayout {
            Layout.fillWidth: true
            columns: 3
            rowSpacing: Tokens.spacing.extraSmall
            columnSpacing: Tokens.spacing.extraSmall

            Repeater {
                model: timerView.presets

                TextButton {
                    required property int modelData

                    Layout.fillWidth: true
                    text: timerView.presetLabel(modelData)
                    type: CountdownTimer.durationSecs === modelData ? TextButton.Filled : TextButton.Tonal
                    horizontalPadding: Tokens.padding.extraSmall
                    disabled: CountdownTimer.running
                    onClicked: CountdownTimer.setDuration(modelData)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            spacing: Tokens.spacing.small

            TextButton {
                Layout.fillWidth: true
                text: CountdownTimer.finished ? Tr.tr("Start again") : CountdownTimer.running ? Tr.tr("Pause") : CountdownTimer.active ? Tr.tr("Resume") : Tr.tr("Start")
                type: TextButton.Filled
                onClicked: CountdownTimer.toggle()
            }

            TextButton {
                visible: CountdownTimer.active
                text: CountdownTimer.finished ? Tr.tr("Dismiss") : Tr.tr("Reset")
                type: TextButton.Text
                onClicked: CountdownTimer.finished ? CountdownTimer.dismiss() : CountdownTimer.reset()
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }

    component StopwatchView: ColumnLayout {
        id: stopwatchView

        readonly property string statusText: {
            if (Stopwatch.running)
                return Tr.tr("Running");
            if (Stopwatch.active)
                return Tr.tr("Stopped");
            return Tr.tr("Ready to start");
        }

        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Tokens.spacing.medium

        // The reading, in the monospaced face: hundredths change too fast for a proportional one,
        // where every digit that comes and goes shifts everything beside it
        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.extraLarge
            horizontalAlignment: Text.AlignHCenter
            text: Stopwatch.display
            color: Stopwatch.running ? Colours.palette.m3primary : Colours.palette.m3onSurface
            font: Tokens.font.mono.builders.large.size(Tokens.font.headline.small.pointSize).weight(Font.Bold).build()
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: stopwatchView.statusText
            animate: true
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.medium
        }

        // What the lap in progress has run for, which the big reading cannot say on its own
        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: -Tokens.spacing.small
            horizontalAlignment: Text.AlignHCenter
            visible: Stopwatch.laps.length > 0
            // TRANSLATORS: %1 = a lap number, %2 = how long that lap has been running
            text: Tr.tr("Lap %1 · %2").arg(Stopwatch.laps.length + 1).arg(Stopwatch.format(Stopwatch.currentSplit))
            color: Colours.palette.m3outline
            font: Tokens.font.mono.small
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            spacing: Tokens.spacing.small

            TextButton {
                Layout.fillWidth: true
                text: Stopwatch.running ? Tr.tr("Pause") : Stopwatch.active ? Tr.tr("Resume") : Tr.tr("Start")
                type: TextButton.Filled
                onClicked: Stopwatch.toggle()
            }

            TextButton {
                Layout.fillWidth: true
                text: Tr.trCtx("Lap", "stopwatch button")
                type: TextButton.Tonal
                disabled: !Stopwatch.running
                onClicked: Stopwatch.lap()
            }

            TextButton {
                visible: Stopwatch.active
                text: Tr.tr("Reset")
                type: TextButton.Text
                onClicked: Stopwatch.reset()
            }
        }

        // The laps taken, newest first. The quickest and the slowest are picked out once there are
        // two to compare
        VerticalFadeListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: Tokens.spacing.small

            spacing: 0
            model: Stopwatch.laps

            delegate: Item {
                id: lapRow

                required property var modelData

                readonly property bool fastest: lapRow.modelData.index === Stopwatch.fastestLap
                readonly property bool slowest: lapRow.modelData.index === Stopwatch.slowestLap
                readonly property color splitColour: lapRow.fastest ? Colours.palette.m3primary : lapRow.slowest ? Colours.palette.m3error : Colours.palette.m3onSurface

                anchors.left: ListView.view.contentItem.left
                anchors.right: ListView.view.contentItem.right

                implicitHeight: lapLayout.implicitHeight + Tokens.padding.small

                RowLayout {
                    id: lapLayout

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.spacing.small

                    StyledText {
                        Layout.fillWidth: true
                        // TRANSLATORS: %1 = a lap number
                        text: Tr.tr("Lap %1").arg(lapRow.modelData.index)
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.medium
                    }

                    StyledText {
                        text: Stopwatch.format(lapRow.modelData.split)
                        color: lapRow.splitColour
                        font: Tokens.font.mono.small
                    }

                    // The reading the lap was taken at, so the list also reads as a running total
                    StyledText {
                        text: Stopwatch.format(lapRow.modelData.at)
                        color: Colours.palette.m3outline
                        font: Tokens.font.mono.small
                    }
                }
            }
        }
    }
}
