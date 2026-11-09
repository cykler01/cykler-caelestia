pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

// NOTE(fork): the countdown, set on a dial rather than from a grid of lengths (see TimerDial.qml).
// Drag the rim for anything up to an hour, tap the middle to type anything at all, and there is
// one button under it: start, pause, pick it back up, start it again. Reset only turns up once
// there is something to reset.
Item {
    id: root

    readonly property color accent: CountdownTimer.finished ? Colours.palette.m3tertiary : CountdownTimer.running ? Colours.palette.m3primary : Colours.palette.m3secondary

    readonly property string statusText: {
        if (CountdownTimer.finished)
            return Tr.tr("Time's up");
        if (CountdownTimer.running)
            return Tr.tr("Ends at %1").arg(Qt.formatTime(new Date(CountdownTimer.endAt), Units.twelveHourClock ? "h:mm A" : "HH:mm"));
        if (CountdownTimer.active)
            return Tr.tr("Paused");
        return Tr.tr("Drag the dial, or tap to type");
    }

    // A lone number is minutes, "1:30" is a minute and a half and "1:02:30" an hour, two minutes
    // and a half. Zero comes back for anything that is not a time, so the timer is left alone
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
        const secs = root.durationFrom(value);
        if (secs > 0)
            CountdownTimer.setDuration(Math.min(secs, 24 * 3600));
    }

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top

        spacing: Tokens.spacing.large

        TimerDial {
            id: dial

            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Tokens.spacing.extraLarge

            implicitWidth: 220
            implicitHeight: 220

            seconds: CountdownTimer.durationSecs
            // It empties as the time goes rather than standing at what was set
            shownSeconds: CountdownTimer.active ? CountdownTimer.remaining : CountdownTimer.durationSecs
            // Nothing to drag while it is counting: the length is what was already decided
            interactive: !CountdownTimer.running && !CountdownTimer.finished
            accent: root.accent

            onMoved: secs => CountdownTimer.setDuration(secs)

            ColumnLayout {
                anchors.centerIn: parent

                spacing: 0

                StyledText {
                    Layout.alignment: Qt.AlignHCenter

                    opacity: entry.activeFocus ? 0 : 1
                    text: CountdownTimer.displayHms
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.clock.size(Tokens.font.title.medium.pointSize).weight(Font.Bold).build()

                    Behavior on opacity {
                        Anim {
                            type: Anim.FastEffects
                        }
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: dial.centreRadius * 2

                    opacity: entry.activeFocus ? 0 : 1
                    horizontalAlignment: Text.AlignHCenter
                    text: root.statusText
                    animate: true
                    color: CountdownTimer.finished ? Colours.palette.m3tertiary : Colours.palette.m3outline
                    font: Tokens.font.label.small
                    wrapMode: Text.WordWrap
                }
            }

            // The same place, as a field for as long as it holds the keyboard. The readout is
            // hidden rather than swapped away, so a tap that never gets the keyboard leaves the
            // time on show
            StyledTextField {
                id: entry

                anchors.centerIn: parent
                width: dial.centreRadius * 1.7

                type: StyledTextField.Filled
                enabled: !CountdownTimer.running
                opacity: activeFocus ? 1 : 0
                horizontalAlignment: TextInput.AlignHCenter
                verticalPadding: Tokens.padding.small
                font: Tokens.font.clock.size(Tokens.font.title.small.pointSize).weight(Font.Bold).build()
                validator: RegularExpressionValidator {
                    regularExpression: /[0-9:]{0,8}/
                }

                // Filled in with what the dial says now, ready to be typed over
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

            // The middle of the dial starts the entry; the rim is the drag's (see TimerDial)
            MouseArea {
                anchors.centerIn: parent

                width: dial.centreRadius * 2
                height: dial.centreRadius * 2

                enabled: !CountdownTimer.running && !entry.activeFocus
                cursorShape: Qt.IBeamCursor
                onClicked: entry.forceActiveFocus()
            }
        }

        // The one button. Reset slides out beside it only once there is a count to clear
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.large
            Layout.rightMargin: Tokens.padding.large

            spacing: Tokens.spacing.small

            TextButton {
                Layout.fillWidth: true

                text: CountdownTimer.finished ? Tr.tr("Start again") : CountdownTimer.running ? Tr.tr("Pause") : CountdownTimer.active ? Tr.tr("Resume") : Tr.tr("Start")
                type: TextButton.Filled
                font: Tokens.font.body.medium
                verticalPadding: Tokens.padding.medium
                onClicked: CountdownTimer.toggle()
            }

            IconButton {
                icon: CountdownTimer.finished ? "close" : "refresh"
                type: IconButton.Tonal
                isRound: true
                shapeMorph: true
                padding: Tokens.padding.medium
                // Grows in rather than appearing, so the pill beside it slides over to make room
                scale: CountdownTimer.active ? 1 : 0
                visible: scale > 0.01
                Layout.preferredWidth: implicitWidth * scale
                onClicked: CountdownTimer.finished ? CountdownTimer.dismiss() : CountdownTimer.reset()

                Behavior on scale {
                    Anim {
                        type: Anim.DefaultSpatial
                    }
                }
            }
        }
    }
}
