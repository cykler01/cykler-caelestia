pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

// The timer panel the utilities panel's timer button opens over the sidebar's tabs: how long, then start it. The
// countdown itself lives in CountdownTimer, so it keeps going (and still rings) while the sidebar is shut, with the
// ring above the bar's clock carrying on where this leaves off
ColumnLayout {
    id: root

    readonly property var presets: [5, 15, 30, 60]

    readonly property string statusText: {
        if (CountdownTimer.finished)
            return Tr.tr("Time's up");
        if (CountdownTimer.running)
            return Tr.tr("Ends at %1").arg(Qt.formatTime(new Date(CountdownTimer.endAt), Units.twelveHourClock ? "h:mm A" : "HH:mm"));
        if (CountdownTimer.active)
            return Tr.tr("Paused with %1 left").arg(CountdownTimer.display);
        return Tr.tr("Ready to start");
    }

    // A lone number is minutes, "1:30" is a minute and a half and "1:02:30" an hour, two minutes and a half. Zero
    // comes back for anything that is not a time, so the caller can leave the timer alone
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

    // A day is more than anyone needs, and keeps a slipped keystroke from setting a timer that never rings
    function commitTime(value: string): void {
        const secs = root.durationFrom(value);
        if (secs > 0)
            CountdownTimer.setDuration(Math.min(secs, 24 * 3600));
    }

    spacing: Tokens.spacing.medium

    StyledText {
        Layout.fillWidth: true
        text: Tr.tr("Timer")
        font: Tokens.font.title.small
    }

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

        // The same place, as a field for as long as it holds the keyboard. The readout is hidden rather than
        // swapped away, so a click that never gets the keyboard leaves the time on show
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
                    root.commitTime(text);
                }
            }

            onAccepted: {
                root.commitTime(text);
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
        text: root.statusText
        animate: true
        color: CountdownTimer.finished ? Colours.palette.m3tertiary : Colours.palette.m3onSurfaceVariant
        font: Tokens.font.label.medium
    }

    // The four lengths that cover most of it, two to a row
    GridLayout {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.small
        columns: 2
        rowSpacing: Tokens.spacing.extraSmall
        columnSpacing: Tokens.spacing.extraSmall

        Repeater {
            model: root.presets

            TextButton {
                required property int modelData

                Layout.fillWidth: true
                text: Tr.trN("%n min", "%n mins", modelData)
                type: CountdownTimer.durationSecs === modelData * 60 ? TextButton.Filled : TextButton.Tonal
                disabled: CountdownTimer.running
                onClicked: CountdownTimer.setDuration(modelData * 60)
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
